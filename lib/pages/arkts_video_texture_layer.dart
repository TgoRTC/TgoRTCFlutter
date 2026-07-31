import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

/// One ArkTS-controlled video rectangle in [TgoFlutterVideoTextureLayer].
///
/// Coordinates are fractions of the FlutterPage's available size. This avoids
/// mixing ArkTS vp/px values with Flutter logical pixels.
class TgoFlutterVideoTile {
  const TgoFlutterVideoTile({
    required this.tileId,
    required this.uid,
    required this.isLocal,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.zIndex,
    required this.visible,
    required this.mirror,
    required this.fit,
  });

  final String tileId;
  final String uid;
  final bool isLocal;
  final double left;
  final double top;
  final double width;
  final double height;
  final int zIndex;
  final bool visible;
  final bool? mirror;
  final String fit;

  factory TgoFlutterVideoTile.fromMap(Map<dynamic, dynamic> value) {
    final tileId = _requiredString(value, 'tileId');
    final uid = _requiredString(value, 'uid');
    final isLocal = _requiredBool(value, 'isLocal');
    final left = _normalised(value, 'left');
    final top = _normalised(value, 'top');
    final width = _normalised(value, 'width');
    final height = _normalised(value, 'height');
    final zIndex = _integer(value['zIndex'], 'zIndex', fallback: 0);
    final visible = _boolean(value['visible'], 'visible', fallback: true);
    final mirror = value['mirror'] == null
        ? null
        : _boolean(value['mirror'], 'mirror', fallback: false);
    final fit = value['fit'] is String ? value['fit'] as String : 'cover';

    if (tileId.isEmpty || uid.isEmpty) {
      throw ArgumentError('tileId and uid must not be empty.');
    }
    if (width <= 0 || height <= 0 || left + width > 1 || top + height > 1) {
      throw ArgumentError('Tile rect must stay inside the 0..1 viewport.');
    }
    if (fit != 'cover' && fit != 'contain') {
      throw ArgumentError('fit must be cover or contain.');
    }
    return TgoFlutterVideoTile(
      tileId: tileId,
      uid: uid,
      isLocal: isLocal,
      left: left,
      top: top,
      width: width,
      height: height,
      zIndex: zIndex,
      visible: visible,
      mirror: mirror,
      fit: fit,
    );
  }

  static String _requiredString(Map<dynamic, dynamic> value, String key) {
    final raw = value[key];
    if (raw is! String) throw ArgumentError('$key must be a string.');
    return raw;
  }

  static bool _requiredBool(Map<dynamic, dynamic> value, String key) {
    final raw = value[key];
    if (raw is! bool) throw ArgumentError('$key must be a boolean.');
    return raw;
  }

  static bool _boolean(dynamic value, String key, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is! bool) throw ArgumentError('$key must be a boolean.');
    return value;
  }

  static int _integer(dynamic value, String key, {required int fallback}) {
    if (value == null) return fallback;
    if (value is! num || !value.isFinite || value.roundToDouble() != value) {
      throw ArgumentError('$key must be an integer.');
    }
    return value.toInt();
  }

  static double _normalised(Map<dynamic, dynamic> value, String key) {
    final raw = value[key];
    if (raw is! num || !raw.isFinite) {
      throw ArgumentError('$key must be a finite number.');
    }
    final result = raw.toDouble();
    if (result < 0 || result > 1) {
      throw ArgumentError('$key must be in the range 0..1.');
    }
    return result;
  }
}

/// Receives ArkTS layout commands for the Flutter Texture video layer.
///
/// This controller is deliberately separate from the XComponent surface
/// manager. Applications may keep the legacy surface path enabled while they
/// migrate individual meeting pages to the Flutter Texture path.
class TgoFlutterVideoLayoutController extends ChangeNotifier {
  TgoFlutterVideoLayoutController._();

  static final TgoFlutterVideoLayoutController instance =
      TgoFlutterVideoLayoutController._();

  List<TgoFlutterVideoTile> _tiles = const [];
  Duration _animationDuration = Duration.zero;
  Curve _animationCurve = Curves.linear;

  List<TgoFlutterVideoTile> get tiles => _tiles;
  Duration get animationDuration => _animationDuration;
  Curve get animationCurve => _animationCurve;

  void updateFromBridge(dynamic arguments) {
    if (arguments is! Map<dynamic, dynamic>) {
      throw ArgumentError('Layout arguments must be a map.');
    }
    final rawTiles = arguments['tiles'];
    if (rawTiles is! List<dynamic>) {
      throw ArgumentError('tiles must be a list.');
    }
    final durationMs = TgoFlutterVideoTile._integer(
      arguments['animationDurationMs'],
      'animationDurationMs',
      fallback: 0,
    );
    if (durationMs < 0 || durationMs > 5000) {
      throw ArgumentError('animationDurationMs must be in the range 0..5000.');
    }

    final ids = <String>{};
    final parsed = <TgoFlutterVideoTile>[];
    for (final rawTile in rawTiles) {
      if (rawTile is! Map<dynamic, dynamic>) {
        throw ArgumentError('Each tile must be a map.');
      }
      final tile = TgoFlutterVideoTile.fromMap(rawTile);
      if (!ids.add(tile.tileId)) {
        throw ArgumentError('tileId must be unique: ${tile.tileId}');
      }
      parsed.add(tile);
    }
    parsed.sort((a, b) {
      final order = a.zIndex.compareTo(b.zIndex);
      return order != 0 ? order : a.tileId.compareTo(b.tileId);
    });
    _tiles = List<TgoFlutterVideoTile>.unmodifiable(parsed);
    _animationDuration = Duration(milliseconds: durationMs);
    _animationCurve = _curveFor(arguments['animationCurve']);
    notifyListeners();
  }

  void clear() {
    if (_tiles.isEmpty) return;
    _tiles = const [];
    _animationDuration = Duration.zero;
    _animationCurve = Curves.linear;
    notifyListeners();
  }

  /// Rebuilds tiles after a participant or track changes without changing
  /// their ArkTS-owned geometry.
  void refreshTracks() => notifyListeners();

  Curve _curveFor(dynamic raw) {
    switch (raw) {
      case null:
      case 'linear':
        return Curves.linear;
      case 'easeIn':
        return Curves.easeIn;
      case 'easeOut':
        return Curves.easeOut;
      case 'easeInOut':
        return Curves.easeInOut;
      default:
        throw ArgumentError(
          'animationCurve must be linear, easeIn, easeOut or easeInOut.',
        );
    }
  }
}

/// Video-only Flutter layer intended to be hosted by one ArkTS [FlutterPage].
///
/// ArkTS owns the meeting UI and sends normalised rectangles through
/// `setFlutterVideoLayout`. This widget owns only WebRTC Flutter Textures, so
/// `cover` and `contain` use Flutter's normal texture rendering path.
class TgoFlutterVideoTextureLayer extends StatefulWidget {
  const TgoFlutterVideoTextureLayer(
      {super.key, this.backgroundColor = Colors.black});

  final Color backgroundColor;

  @override
  State<TgoFlutterVideoTextureLayer> createState() =>
      _TgoFlutterVideoTextureLayerState();
}

class _TgoFlutterVideoTextureLayerState
    extends State<TgoFlutterVideoTextureLayer> {
  late final void Function(TgoParticipant) _participantChanged;

  @override
  void initState() {
    super.initState();
    _participantChanged = (_) {
      TgoFlutterVideoLayoutController.instance.refreshTracks();
    };
    TgoFlutterVideoLayoutController.instance.addListener(_onLayoutChanged);
    TgoRTC.instance.participantManager
        .addNewParticipantListener(_participantChanged);
    TgoRTC.instance.participantManager
        .addParticipantJoinedListener(_participantChanged);
  }

  @override
  void dispose() {
    TgoFlutterVideoLayoutController.instance.removeListener(_onLayoutChanged);
    TgoRTC.instance.participantManager
        .removeNewParticipantListener(_participantChanged);
    TgoRTC.instance.participantManager
        .removeParticipantJoinedListener(_participantChanged);
    super.dispose();
  }

  void _onLayoutChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tiles = TgoFlutterVideoLayoutController.instance.tiles;
    return ColoredBox(
      color: widget.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final tile in tiles)
                if (tile.visible)
                  _buildTile(
                    tile,
                    constraints.maxWidth,
                    constraints.maxHeight,
                    TgoFlutterVideoLayoutController.instance.animationDuration,
                    TgoFlutterVideoLayoutController.instance.animationCurve,
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTile(
    TgoFlutterVideoTile tile,
    double parentWidth,
    double parentHeight,
    Duration animationDuration,
    Curve animationCurve,
  ) {
    final participant = _participantFor(tile);
    final trackRenderer = TgoTrackRenderer(
      source: TrackSource.camera,
      fit: tile.fit == 'contain'
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      mirrorMode: (tile.mirror ?? TgoRTC.instance.options.mirror)
          ? VideoViewMirrorMode.mirror
          : VideoViewMirrorMode.off,
    )..setParticipant(participant);

    return AnimatedPositioned(
      key: ValueKey<String>(tile.tileId),
      duration: animationDuration,
      curve: animationCurve,
      left: tile.left * parentWidth,
      top: tile.top * parentHeight,
      width: tile.width * parentWidth,
      height: tile.height * parentHeight,
      child: IgnorePointer(
        child: ClipRect(
          child: trackRenderer.build(),
        ),
      ),
    );
  }

  TgoParticipant? _participantFor(TgoFlutterVideoTile tile) {
    try {
      if (tile.isLocal) {
        final local = TgoRTC.instance.participantManager.getLocalParticipant();
        return local.uid == tile.uid ? local : null;
      }
      for (final participant
          in TgoRTC.instance.participantManager.getRemoteParticipants()) {
        if (participant.uid == tile.uid) return participant;
      }
    } catch (_) {
      // The ArkTS layout may arrive before joinRoom creates participants.
    }
    return null;
  }
}

/// Minimal FlutterPage root for the ArkTS-controlled Texture renderer.
class TgoFlutterVideoTextureApp extends StatelessWidget {
  const TgoFlutterVideoTextureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TgoFlutterVideoTextureLayer(),
    );
  }
}
