import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

/// Video track renderer for displaying participant video.
///
/// Use this class to render video from a participant's camera or screen share.
///
/// ## Usage
///
/// ```dart
/// final renderer = TgoTrackRenderer(
///   source: TrackSource.camera,
///   fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
/// );
/// renderer.setParticipant(participant);
///
/// // In your widget tree
/// return renderer.build();
/// ```
class TgoTrackRenderer {
  TgoParticipant? _participant;
  TrackSource source;
  RTCVideoViewObjectFit fit;
  bool? mirror;
  Widget? placeholder;
  ValueChanged<bool>? onTrackChange;

  TgoTrackRenderer({
    this.source = TrackSource.camera,
    this.fit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    this.mirror,
    this.placeholder,
    this.onTrackChange,
  });

  void setParticipant(TgoParticipant participant) {
    _participant = participant;
  }

  void clear() {
    _participant = null;
  }

  /// 返回可渲染的 Widget
  Widget build() {
    return _TgoTrackRendererWidget(
      participant: _participant,
      source: source,
      fit: fit,
      mirror: mirror,
      placeholder: placeholder,
      onTrackChange: onTrackChange,
    );
  }
}

class _TgoTrackRendererWidget extends StatefulWidget {
  final TgoParticipant? participant;
  final TrackSource source;
  final RTCVideoViewObjectFit fit;
  final bool? mirror;
  final Widget? placeholder;
  final ValueChanged<bool>? onTrackChange;

  const _TgoTrackRendererWidget({
    this.participant,
    required this.source,
    required this.fit,
    this.mirror,
    this.placeholder,
    this.onTrackChange,
  });

  @override
  State<_TgoTrackRendererWidget> createState() =>
      _TgoTrackRendererWidgetState();
}

class _TgoTrackRendererWidgetState extends State<_TgoTrackRendererWidget> {
  VideoTrack? _videoTrack;

  @override
  void initState() {
    super.initState();
    _updateTrack();
    _addListeners();
  }

  @override
  void didUpdateWidget(covariant _TgoTrackRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant != widget.participant) {
      _removeListeners(oldWidget.participant);
      _addListeners();
      _updateTrack();
    }
  }

  @override
  void dispose() {
    _removeListeners(widget.participant);
    super.dispose();
  }

  void _addListeners() {
    widget.participant?.addCameraStatusListener(_onCameraChanged);
    widget.participant?.addJoinedListener(_onJoined);
    widget.participant?.addTrackPublishedListener(_onTrackPublished);
  }

  void _removeListeners(TgoParticipant? participant) {
    participant?.removeCameraStatusListener(_onCameraChanged);
    participant?.removeJoinedListener(_onJoined);
    participant?.removeTrackPublishedListener(_onTrackPublished);
  }

  void _onCameraChanged(bool enabled) {
    _updateTrack();
  }

  void _onJoined() {
    _updateTrack();
  }

  void _onTrackPublished() {
    _updateTrack();
  }

  void _updateTrack() {
    final nextTrack = widget.participant?.getVideoTrack(source: widget.source);
    if (_videoTrack == nextTrack) {
      return;
    }
    setState(() {
      _videoTrack = nextTrack;
    });
    widget.onTrackChange?.call(_videoTrack != null);
  }

  @override
  Widget build(BuildContext context) {
    if (_videoTrack == null) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    return VideoTrackRenderer(
      _videoTrack!,
      fit: widget.fit,
      mirrorMode: (widget.mirror ?? TgoRTC.instance.options.mirror)
          ? VideoViewMirrorMode.mirror
          : VideoViewMirrorMode.off,
    );
  }
}
