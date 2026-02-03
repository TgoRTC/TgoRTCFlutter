import 'package:tgortcflutter/tgortc.dart';

/// Utility class to serialize SDK entities to Maps for MethodChannel communication.
class TgoSerializers {
  /// Serializes [RoomInfo] to a Map.
  static Map<String, dynamic> roomInfoToMap(RoomInfo? info) {
    if (info == null) return {};
    return {
      'roomName': info.roomName,
      'token': info.token,
      'url': info.url,
      'loginUID': info.loginUID,
      'creatorUID': info.creatorUID,
      'maxParticipants': info.maxParticipants,
      'rtcType': info.rtcType,
      'isP2P': info.isP2P,
      'uidList': info.uidList,
      'timeout': info.timeout,
    };
  }

  /// Serializes [TgoParticipant] to a Map.
  static Map<String, dynamic> participantToMap(TgoParticipant participant) {
    return {
      'uid': participant.uid,
      'isLocal': participant.isLocal,
      'micEnabled': participant.getMicrophoneEnabled(),
      'cameraEnabled': participant.getCameraEnabled(),
      'isSpeaking': participant.isJoined, // isJoined might be slightly different but used as placeholder
    };
  }

  /// Serializes a list of [TgoParticipant] to a List of Maps.
  static List<Map<String, dynamic>> participantListToMap(List<TgoParticipant> participants) {
    return participants.map((p) => participantToMap(p)).toList();
  }

  /// Serializes [VideoInfo] to a Map.
  static Map<String, dynamic> videoInfoToMap(VideoInfo info) {
    return {
      'width': info.width,
      'height': info.height,
      'bitrate': info.bitrate,
      'frameRate': info.frameRate,
      'layerId': info.layerId,
      'qualityLimitationReason': info.qualityLimitationReason,
    };
  }

  /// Converts [ConnectStatus] enum to integer.
  static int connectStatusToInt(ConnectStatus status) {
    switch (status) {
      case ConnectStatus.connecting:
        return 0;
      case ConnectStatus.connected:
        return 1;
      case ConnectStatus.disconnected:
        return 2;
      default:
        return 2;
    }
  }
}
