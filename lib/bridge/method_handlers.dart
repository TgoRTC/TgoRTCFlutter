import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:tgortcflutter/tgortc.dart';
import 'package:tgortcflutter/bridge/serializers.dart';
import 'package:tgortcflutter/bridge/event_forwarder.dart';
import 'package:tgortcflutter/bridge/tgo_video_surface_manager.dart';
import 'package:tgortcflutter/utils/logger.dart';

/// Handler for MethodChannel calls from HarmonyOS.
class TgoMethodHandlers {
  static void _log(String msg) {
    developer.log('[TgoMethodHandlers] $msg', name: 'BRIDGE');
    print('[TgoMethodHandlers] $msg'); // Also print for HarmonyOS hilog
  }

  static Future<dynamic> handleMethodCall(MethodCall call) async {
    _log('handleMethodCall START: method=${call.method}');
    Logger.info('MethodChannel call: ${call.method}');

    try {
      final result = await _dispatchMethodCall(call);
      _log('handleMethodCall SUCCESS: method=${call.method}');
      return result;
    } catch (e, stackTrace) {
      _log('handleMethodCall ERROR: method=${call.method}, error=$e');
      _log('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<dynamic> _dispatchMethodCall(MethodCall call) async {
    switch (call.method) {
      // Command-type APIs
      case 'init':
        return _init(call.arguments);
      case 'joinRoom':
        return _joinRoom(call.arguments);
      case 'leaveRoom':
        return _leaveRoom();
      case 'setMicrophoneEnabled':
        return _setMicrophoneEnabled(call.arguments as bool);
      case 'setCameraEnabled':
        return _setCameraEnabled(call.arguments as bool);
      case 'setSpeakerphoneOn':
        return _setSpeakerphoneOn(call.arguments as bool);
      case 'switchCamera':
        return _switchCamera();
      case 'invite':
        return _invite(call.arguments);
      case 'missed':
        return _missed(call.arguments);
      case 'attachVideoSurface':
        return _attachVideoSurface(call.arguments);
      case 'detachVideoSurface':
        return _detachVideoSurface(call.arguments);
      case 'updateVideoSurface':
        return _updateVideoSurface(call.arguments);
      case 'setFlutterVideoLayout':
        return _setFlutterVideoLayout(call.arguments);
      case 'clearFlutterVideoLayout':
        return _clearFlutterVideoLayout();

      // Query-type APIs
      case 'getConnectStatus':
        return _getConnectStatus();
      case 'getCurrentRoomInfo':
        return _getCurrentRoomInfo();
      case 'getAllParticipants':
        return _getAllParticipants();
      case 'isCalling':
        return _isCalling();
      case 'isSpeakerOn':
        return _isSpeakerOn();
      case 'getCameraPosition':
        return _getCameraPosition();

      default:
        throw PlatformException(
          code: 'unsupported_method',
          message: 'The method ${call.method} is not implemented.',
        );
    }
  }

  // --- Implementations ---

  static Future<void> _init(dynamic args) async {
    final Map<dynamic, dynamic> map = args as Map<dynamic, dynamic>;
    final options = Options()
      ..debug = map['debug'] ?? true
      ..mirror = map['mirror'] ?? true;
    TgoRTC.instance.init(options);
  }

  static Future<void> _joinRoom(dynamic args) async {
    _log('_joinRoom START');
    try {
      final Map<dynamic, dynamic> map = args as Map<dynamic, dynamic>;
      _log(
          '_joinRoom parsed args: roomName=${map['roomName']}, url=${map['url']}');

      final roomInfo = RoomInfo(
        map['roomName'] ?? '',
        map['token'] ?? '',
        map['url'] ?? '',
        map['loginUID'] ?? '',
        map['creatorUID'] ?? '',
      )
        ..maxParticipants = map['maxParticipants'] ?? 9
        ..rtcType = map['rtcType'] == 1 ? RTCType.video : RTCType.audio
        ..isP2P = map['isP2P'] ?? false
        ..uidList = List<String>.from(map['uidList'] ?? [])
        ..timeout = map['timeout'] ?? 30;

      _log('_joinRoom created RoomInfo, calling roomManager.joinRoom');

      await TgoRTC.instance.roomManager.joinRoom(
        roomInfo,
        micEnabled: map['micEnabled'] ?? true,
        cameraEnabled: map['cameraEnabled'] ?? true,
      );

      _log('_joinRoom roomManager.joinRoom completed');
    } catch (e, stackTrace) {
      _log('_joinRoom ERROR: $e');
      _log('_joinRoom stackTrace: $stackTrace');
      rethrow;
    }
  }

  static Future<void> _leaveRoom() async {
    await TgoRTC.instance.roomManager.leaveRoom();
  }

  static Future<void> _setMicrophoneEnabled(bool enabled) async {
    await TgoRTC.instance.participantManager
        .getLocalParticipant()
        .setMicrophoneEnabled(enabled);
  }

  static Future<void> _setCameraEnabled(bool enabled) async {
    await TgoRTC.instance.participantManager
        .getLocalParticipant()
        .setCameraEnabled(enabled);
  }

  static Future<void> _setSpeakerphoneOn(bool on) async {
    await TgoRTC.instance.audioManager.setSpeakerphoneOn(on);
    TgoEventForwarder.notifyAudioOutputDeviceChanged();
  }

  static Future<void> _switchCamera() async {
    final participant =
        TgoRTC.instance.participantManager.getLocalParticipant();
    await participant.switchCamera();
    await TgoVideoSurfaceManager.instance.refreshParticipant(
      uid: participant.uid,
      isLocal: true,
      reportBindFailure: true,
    );
  }

  static Future<void> _invite(dynamic args) async {
    final Map<dynamic, dynamic> map = args as Map<dynamic, dynamic>;
    final String roomName = map['roomName'] ?? '';
    final List<String> uids = List<String>.from(map['uids'] ?? []);
    TgoRTC.instance.participantManager.invite(roomName, uids);
  }

  static Future<void> _missed(dynamic args) async {
    final Map<dynamic, dynamic> map = args as Map<dynamic, dynamic>;
    final String roomName = map['roomName'] ?? '';
    final List<String> uids = List<String>.from(map['uids'] ?? []);
    TgoRTC.instance.participantManager.missed(roomName, uids);
  }

  static Future<void> _attachVideoSurface(dynamic args) {
    final map = args as Map<dynamic, dynamic>;
    return TgoVideoSurfaceManager.instance.attach(
      uid: map['uid'] as String? ?? '',
      surfaceId: map['surfaceId'] as String? ?? '',
      isLocal: map['isLocal'] as bool? ?? false,
      mirror: map['mirror'] as bool? ?? false,
      fit: map['fit'] as String? ?? 'cover',
    );
  }

  static Future<void> _detachVideoSurface(dynamic args) {
    final map = args as Map<dynamic, dynamic>;
    return TgoVideoSurfaceManager.instance.detach(
      surfaceId: map['surfaceId'] as String? ?? '',
    );
  }

  static Future<void> _updateVideoSurface(dynamic args) {
    final map = args as Map<dynamic, dynamic>;
    return TgoVideoSurfaceManager.instance.update(
      surfaceId: map['surfaceId'] as String? ?? '',
      mirror: map['mirror'] as bool?,
      fit: map['fit'] as String?,
    );
  }

  /// Updates the Flutter Texture layer while retaining the legacy XComponent
  /// APIs above for applications that still use native Surface rendering.
  static void _setFlutterVideoLayout(dynamic args) {
    try {
      TgoFlutterVideoLayoutController.instance.updateFromBridge(args);
    } on ArgumentError catch (error) {
      throw PlatformException(
        code: 'invalid_flutter_video_layout',
        message: error.message?.toString() ?? error.toString(),
      );
    }
  }

  static void _clearFlutterVideoLayout() {
    TgoFlutterVideoLayoutController.instance.clear();
  }

  static Map<String, dynamic> _getConnectStatus() {
    final roomManager = TgoRTC.instance.roomManager;
    return {
      'roomName': roomManager.connectStatusRoomName,
      'status': TgoSerializers.connectStatusToInt(roomManager.connectStatus),
      'reason': roomManager.connectStatusReason,
    };
  }

  static Map<String, dynamic> _getCurrentRoomInfo() {
    return TgoSerializers.roomInfoToMap(
        TgoRTC.instance.roomManager.currentRoomInfo);
  }

  static List<Map<String, dynamic>> _getAllParticipants() {
    final participants =
        TgoRTC.instance.participantManager.getAllParticipants();
    return TgoSerializers.participantListToMap(participants);
  }

  static bool _isCalling() {
    return TgoRTC.instance.roomManager.isCalling();
  }

  static bool _isSpeakerOn() {
    return TgoRTC.instance.audioManager.isSpeakerOn;
  }

  static String _getCameraPosition() {
    final pos = TgoRTC.instance.participantManager
        .getLocalParticipant()
        .getCameraPosition();
    return pos == TgoCameraPosition.front ? 'front' : 'back';
  }
}
