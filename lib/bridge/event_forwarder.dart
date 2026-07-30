import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tgortcflutter/tgortc.dart';
import 'package:tgortcflutter/bridge/serializers.dart';

/// Forwards SDK events to HarmonyOS via MethodChannel.
class TgoEventForwarder {
  static MethodChannel? _channel;
  static bool _isInitialized = false;
  static TgoParticipant? _localParticipant;
  static final Set<TgoParticipant> _remoteLeaveListeners = {};

  /// Initializes the event forwarder.
  static void init(MethodChannel channel) {
    _channel = channel;
    if (_isInitialized) return;
    _isInitialized = true;
    _setupListeners();
  }

  static void _setupListeners() {
    // Room events are the authoritative source of connection state. Do not
    // access the local participant here: bridge registration happens before a
    // room is joined.
    TgoRTC.instance.roomManager.addConnectListener((roomName, status, reason) {
      _emit('onConnectStatusChanged', {
        'roomName': roomName,
        'status': TgoSerializers.connectStatusToInt(status),
        'reason': reason,
      });

      if (status == ConnectStatus.connected) {
        _listenToLocalParticipant();
        _notifyParticipantsChanged();
      } else if (status == ConnectStatus.disconnected) {
        _notifyParticipantsChanged();
        _emit('onRoomDisconnected', {
          'roomName': roomName,
          'reason': reason,
        });
        _localParticipant?.removeMicrophoneStatusListener(_onLocalMediaChanged);
        _localParticipant?.removeCameraStatusListener(_onLocalMediaChanged);
        _localParticipant = null;
        _remoteLeaveListeners.clear();
      }
    });

    TgoRTC.instance.participantManager.addNewParticipantListener((participant) {
      // A new uidList-only member must be shown as a pending participant. A
      // newly connected LiveKit participant is forwarded by the joined
      // listener below, avoiding a duplicate full-list event.
      if (!participant.isJoined) {
        _notifyParticipantsChanged();
      }
    });

    // uidList can create a placeholder before the remote user enters the
    // LiveKit room. This listener covers its later transition to a real
    // RemoteParticipant; addNewParticipantListener alone cannot observe it.
    TgoRTC.instance.participantManager
        .addParticipantJoinedListener((participant) {
      _listenToJoinedRemoteParticipant(participant);
      // The transition may be discovered while a participant snapshot is
      // being built. Defer the next snapshot to prevent synchronous re-entry.
      scheduleMicrotask(_notifyParticipantsChanged);
    });

    TgoRTC.instance.audioManager.addDeviceChangeListener((_) {
      _notifyAudioOutputDeviceChanged();
    });
  }

  static void _listenToLocalParticipant() {
    final local = TgoRTC.instance.participantManager.getLocalParticipant();
    if (identical(_localParticipant, local)) return;

    _localParticipant?.removeMicrophoneStatusListener(_onLocalMediaChanged);
    _localParticipant?.removeCameraStatusListener(_onLocalMediaChanged);
    _localParticipant = local;
    local.addMicrophoneStatusListener(_onLocalMediaChanged);
    local.addCameraStatusListener(_onLocalMediaChanged);
  }

  static void _onLocalMediaChanged(bool _) {
    _notifyLocalMediaStatusChanged();
    _notifyParticipantsChanged();
  }

  static void _listenToJoinedRemoteParticipant(TgoParticipant participant) {
    if (participant.isLocal || !participant.isJoined) return;
    if (!_remoteLeaveListeners.add(participant)) return;

    participant.addLeaveListener(() {
      _remoteLeaveListeners.remove(participant);
      final roomName =
          TgoRTC.instance.roomManager.currentRoomInfo?.roomName ?? '';
      _emit('onRemoteParticipantLeft', {
        'roomName': roomName,
        'uid': participant.uid,
        'reason': 'left',
      });
      // TgoParticipant notifies listeners before ParticipantManager removes
      // it from its cache. Queue the refresh so ArkTS receives the final list.
      scheduleMicrotask(_notifyParticipantsChanged);
    });
  }

  static void _notifyParticipantsChanged() {
    // A disconnect clears room state, so the final empty-list notification is
    // still useful and must not recreate a local participant.
    final roomInfo = TgoRTC.instance.roomManager.currentRoomInfo;
    final participants = roomInfo == null
        ? <TgoParticipant>[]
        : TgoRTC.instance.participantManager.getAllParticipants();
    for (final participant in participants) {
      _listenToJoinedRemoteParticipant(participant);
    }
    _emit('onParticipantsChanged', {
      'count': participants.length,
      'participants': TgoSerializers.participantListToMap(participants),
    });
  }

  static void _notifyLocalMediaStatusChanged() {
    final local = _localParticipant;
    if (local == null) return;
    _emit('onLocalMediaStatusChanged', {
      'micEnabled': local.getMicrophoneEnabled(),
      'cameraEnabled': local.getCameraEnabled(),
    });
  }

  /// Called after a successful speakerphone command and when the platform
  /// reports a hardware-route change.
  static void notifyAudioOutputDeviceChanged() {
    _notifyAudioOutputDeviceChanged();
  }

  static void _notifyAudioOutputDeviceChanged() {
    final audioManager = TgoRTC.instance.audioManager;
    final speakerphoneOn = audioManager.speakerOn ?? audioManager.isSpeakerOn;
    _emit('onAudioOutputDeviceChanged', {
      'speakerphoneOn': speakerphoneOn,
      'deviceName': speakerphoneOn ? 'Speakerphone' : 'Earpiece',
    });
  }

  static void _emit(String method, Map<String, dynamic> arguments) {
    unawaited(
        _channel?.invokeMethod<void>(method, arguments).catchError((_) {}));
  }
}
