import 'package:flutter/services.dart';
import 'package:tgortcflutter/tgortc.dart';
import 'package:tgortcflutter/bridge/serializers.dart';

/// Forwards SDK events to HarmonyOS via MethodChannel.
class TgoEventForwarder {
  static MethodChannel? _channel;

  /// Initializes the event forwarder.
  static void init(MethodChannel channel) {
    _channel = channel;
    _setupListeners();
  }

  static void _setupListeners() {
    // 1. Connection status events
    TgoRTC.instance.roomManager.addConnectListener((roomName, status, reason) {
      _channel?.invokeMethod('onConnectStatusChanged', {
        'roomName': roomName,
        'status': TgoSerializers.connectStatusToInt(status),
        'reason': reason,
      });
    });

    // 2. Participant list change events
    TgoRTC.instance.participantManager.addNewParticipantListener((participant) {
      _notifyParticipantsChanged();
    });
    
    // We also need to listen to existing participants' join/leave to notify OHOS
    // This is a bit tricky as we don't have a global "any participant left" listener in ParticipantManager
    // But we can hook into RoomManager events or add listeners to participants as they appear.
    
    _hookIntoParticipantEvents();
  }

  static void _hookIntoParticipantEvents() {
    // Periodically or on specific triggers, we might want to refresh OHOS
    // For now, let's also hook into the local participant's events as a proxy for media status
    final local = TgoRTC.instance.participantManager.getLocalParticipant();
    
    local.addMicrophoneStatusListener((enabled) {
      _notifyLocalMediaStatusChanged();
    });
    
    local.addCameraStatusListener((enabled) {
      _notifyLocalMediaStatusChanged();
    });

    // Handle remote participant join/leave via the existing RoomManager listeners is already partially done
    // by ParticipantManager which triggers addNewParticipantListener.
    // For "leave", we need to monitor TgoParticipant.addLeaveListener
  }

  static void _notifyParticipantsChanged() {
    final participants = TgoRTC.instance.participantManager.getAllParticipants();
    _channel?.invokeMethod('onParticipantsChanged', {
      'count': participants.length,
      'participants': TgoSerializers.participantListToMap(participants),
    });
  }

  static void _notifyLocalMediaStatusChanged() {
    final local = TgoRTC.instance.participantManager.getLocalParticipant();
    _channel?.invokeMethod('onLocalMediaStatusChanged', {
      'micEnabled': local.getMicrophoneEnabled(),
      'cameraEnabled': local.getCameraEnabled(),
    });
  }
}
