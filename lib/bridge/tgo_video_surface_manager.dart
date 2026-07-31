import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:tgortcflutter/tgortc.dart';

/// Owns the mapping between an ArkTS XComponent Surface and a LiveKit camera
/// track. This class never creates UI; ArkTS owns the XComponent lifecycle.
class TgoVideoSurfaceManager {
  TgoVideoSurfaceManager._internal();

  static final TgoVideoSurfaceManager instance =
      TgoVideoSurfaceManager._internal();
  static const MethodChannel _channel = MethodChannel('com.tgortc/bridge');
  static const int _maxSurfacesPerParticipant = 2;

  final Map<String, _VideoSurfaceBinding> _bindings = {};
  final Set<TgoParticipant> _observedParticipants = {};
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    TgoRTC.instance.roomManager.addConnectListener((_, status, __) {
      if (status == ConnectStatus.disconnected) {
        unawaited(detachAll(reason: 'room_disconnected'));
      }
    });
    TgoRTC.instance.participantManager.addParticipantJoinedListener(
      (participant) {
        _observe(participant);
        // An invited uid may already own a waiting Surface binding. The
        // placeholder keeps the same TgoParticipant instance when LiveKit
        // supplies the real RemoteParticipant, so there may be no later
        // video-track callback to wake the binding up.
        unawaited(
          _refreshForParticipant(participant.uid, participant.isLocal),
        );
      },
    );
  }

  Future<void> attach({
    required String uid,
    required String surfaceId,
    required bool isLocal,
    bool mirror = false,
    String fit = 'cover',
  }) async {
    if (surfaceId.isEmpty) {
      throw PlatformException(
        code: 'surface_not_found',
        message: 'surfaceId must come from a loaded ArkTS XComponent.',
      );
    }
    if (fit != 'cover' && fit != 'contain') {
      throw PlatformException(
        code: 'renderer_bind_failed',
        message: 'Unsupported video fit: $fit',
      );
    }

    final roomInfo = TgoRTC.instance.roomManager.currentRoomInfo;
    if (roomInfo == null) {
      throw PlatformException(
        code: 'participant_not_found',
        message: 'No active room.',
      );
    }

    final existing = _bindings[surfaceId];
    if (existing != null &&
        existing.uid == uid &&
        existing.isLocal == isLocal) {
      await update(surfaceId: surfaceId, mirror: mirror, fit: fit);
      return;
    }

    final participant = _findParticipant(uid, isLocal);
    if (participant == null) {
      throw PlatformException(
        code: 'participant_not_found',
        message: 'Participant $uid is not in the current room.',
      );
    }
    _observe(participant);

    final sameParticipantBindings = _bindings.values.where((binding) {
      return binding.uid == uid && binding.isLocal == isLocal;
    }).length;
    if (existing == null &&
        sameParticipantBindings >= _maxSurfacesPerParticipant) {
      throw PlatformException(
        code: 'renderer_bind_failed',
        message:
            'A participant can use at most $_maxSurfacesPerParticipant surfaces.',
      );
    }

    if (existing != null) {
      await _detach(existing, reason: 'surface_rebound');
    }

    final binding = _VideoSurfaceBinding(
      roomName: roomInfo.roomName,
      uid: uid,
      surfaceId: surfaceId,
      isLocal: isLocal,
      mirror: mirror,
      fit: fit,
    );
    _bindings[surfaceId] = binding;
    _emitState(binding, 'waiting_track');

    // A uidList placeholder is a valid pending target. The binding is retained
    // and automatically activated when LiveKit supplies its camera track.
    await _refresh(binding, reportBindFailure: true);
  }

  Future<void> detach({required String surfaceId}) async {
    final binding = _bindings.remove(surfaceId);
    if (binding == null) return;
    await _releaseRenderer(binding);
    _emitState(binding, 'detached');
  }

  Future<void> update({
    required String surfaceId,
    bool? mirror,
    String? fit,
  }) async {
    final binding = _bindings[surfaceId];
    if (binding == null) {
      throw PlatformException(
        code: 'surface_not_found',
        message: 'No renderer is registered for surface $surfaceId.',
      );
    }
    if (fit != null && fit != 'cover' && fit != 'contain') {
      throw PlatformException(
        code: 'renderer_bind_failed',
        message: 'Unsupported video fit: $fit',
      );
    }
    if (mirror != null) binding.mirror = mirror;
    if (fit != null) binding.fit = fit;

    final renderer = binding.renderer;
    if (renderer == null) {
      await _refresh(binding, reportBindFailure: true);
      return;
    }
    try {
      await renderer.updateExternalSurface(
        mirror: binding.mirror,
        fit: binding.fit,
      );
    } catch (error) {
      _emitState(binding, 'error', reason: '$error');
      throw PlatformException(code: 'renderer_bind_failed', message: '$error');
    }
  }

  Future<void> detachAll({String reason = 'detached'}) async {
    final bindings = _bindings.values.toList(growable: false);
    _bindings.clear();
    for (final binding in bindings) {
      await _releaseRenderer(binding);
      _emitState(binding, 'detached', reason: reason);
    }
  }

  void _observe(TgoParticipant participant) {
    if (!_observedParticipants.add(participant)) return;
    participant.addVideoTrackListener((_, __) {
      unawaited(_refreshForParticipant(participant.uid, participant.isLocal));
    });
    participant.addLeaveListener(() {
      unawaited(_detachParticipant(participant.uid, participant.isLocal));
    });
  }

  Future<void> _refreshForParticipant(String uid, bool isLocal) async {
    final bindings = _bindings.values
        .where((binding) => binding.uid == uid && binding.isLocal == isLocal)
        .toList(growable: false);
    for (final binding in bindings) {
      await _refresh(binding);
    }
  }

  Future<void> _detachParticipant(String uid, bool isLocal) async {
    final bindings = _bindings.values
        .where((binding) => binding.uid == uid && binding.isLocal == isLocal)
        .toList(growable: false);
    for (final binding in bindings) {
      _bindings.remove(binding.surfaceId);
      await _releaseRenderer(binding);
      _emitState(binding, 'detached', reason: 'participant_left');
    }
  }

  Future<void> _refresh(_VideoSurfaceBinding binding,
      {bool reportBindFailure = false}) async {
    if (!identical(_bindings[binding.surfaceId], binding)) return;

    final participant = _findParticipant(binding.uid, binding.isLocal);
    if (participant == null || !participant.isJoined) {
      await _releaseRenderer(binding);
      _emitState(binding, 'waiting_track', reason: 'participant_not_ready');
      return;
    }
    _observe(participant);
    final track = participant.getVideoTrack();
    if (track == null || !participant.getCameraEnabled()) {
      await _releaseRenderer(binding);
      _emitState(binding, 'waiting_track', reason: 'track_not_ready');
      return;
    }

    final String? trackId = track.mediaStreamTrack.id;
    if (trackId == null || trackId.isEmpty) {
      await _releaseRenderer(binding);
      _emitState(binding, 'waiting_track', reason: 'track_not_ready');
      return;
    }
    if (binding.renderer != null && binding.trackId == trackId) {
      return;
    }

    await _releaseRenderer(binding);
    final renderer = RTCVideoRenderer();
    try {
      await renderer.initialize();
      binding.renderer = renderer;
      binding.trackId = trackId;
      renderer.onFirstFrameRendered = () {
        if (identical(_bindings[binding.surfaceId], binding)) {
          _emitState(binding, 'rendering');
        }
      };
      await renderer.bindExternalSurface(
        externalSurfaceId: binding.surfaceId,
        stream: track.mediaStream,
        trackId: trackId,
        mirror: binding.mirror,
        fit: binding.fit,
      );
    } catch (error) {
      await _releaseRenderer(binding);
      _emitState(binding, 'error', reason: '$error');
      if (reportBindFailure) {
        throw PlatformException(
          code: 'renderer_bind_failed',
          message: '$error',
        );
      }
    }
  }

  Future<void> _detach(_VideoSurfaceBinding binding,
      {required String reason}) async {
    _bindings.remove(binding.surfaceId);
    await _releaseRenderer(binding);
    _emitState(binding, 'detached', reason: reason);
  }

  Future<void> _releaseRenderer(_VideoSurfaceBinding binding) async {
    final renderer = binding.renderer;
    binding.renderer = null;
    binding.trackId = null;
    if (renderer == null) return;
    try {
      await renderer.dispose();
    } catch (_) {
      // The native surface may already have been destroyed. The binding is
      // still removed and ArkTS receives the detached/error state.
    }
  }

  TgoParticipant? _findParticipant(String uid, bool isLocal) {
    final roomInfo = TgoRTC.instance.roomManager.currentRoomInfo;
    if (roomInfo == null) return null;
    if (isLocal) {
      if (roomInfo.loginUID != uid) return null;
      return TgoRTC.instance.participantManager.getLocalParticipant();
    }
    for (final participant
        in TgoRTC.instance.participantManager.getRemoteParticipants()) {
      if (participant.uid == uid) return participant;
    }
    return null;
  }

  void _emitState(_VideoSurfaceBinding binding, String state,
      {String? reason}) {
    final args = <String, dynamic>{
      'roomName': binding.roomName,
      'surfaceId': binding.surfaceId,
      'uid': binding.uid,
      'state': state,
    };
    if (reason != null && reason.isNotEmpty) args['reason'] = reason;
    unawaited(_channel
        .invokeMethod<void>('onVideoSurfaceStateChanged', args)
        .catchError((_) {}));
  }
}

class _VideoSurfaceBinding {
  _VideoSurfaceBinding({
    required this.roomName,
    required this.uid,
    required this.surfaceId,
    required this.isLocal,
    required this.mirror,
    required this.fit,
  });

  final String roomName;
  final String uid;
  final String surfaceId;
  final bool isLocal;
  bool mirror;
  String fit;
  String? trackId;
  RTCVideoRenderer? renderer;
}
