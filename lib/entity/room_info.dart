import 'const.dart';

/// Room connection information.
///
/// Contains all the information needed to connect to a LiveKit room.
///
/// ## Example
///
/// ```dart
/// final roomInfo = RoomInfo(
///   'my-room',
///   'access-token',
///   'wss://livekit.example.com',
///   'user-123',
///   'creator-456',
/// );
/// ```
class RoomInfo {
  /// The name of the room.
  String roomName;

  /// The access token for authentication.
  String token;

  /// The LiveKit server URL (e.g., "wss://livekit.example.com").
  String url;

  /// Maximum number of participants allowed in the room.
  ///
  /// Defaults to 2 for P2P calls.
  int maxParticipants = 2;

  /// The type of RTC call (audio or video).
  RTCType rtcType = RTCType.audio;

  /// The UID of the current logged-in user.
  String loginUID;

  /// The UID of the room creator.
  String creatorUID;

  /// Whether this is a P2P (peer-to-peer) call.
  ///
  /// Defaults to true.
  bool isP2P = true;

  /// List of participant UIDs in the room.
  List<String> uidList = [];

  /// Timeout in seconds for waiting for participants to join.
  ///
  /// Defaults to 30 seconds.
  int timeout = 30;

  /// Creates a new RoomInfo instance.
  ///
  /// [roomName] - The name of the room.
  /// [token] - The access token for authentication.
  /// [url] - The LiveKit server URL.
  /// [loginUID] - The UID of the current logged-in user.
  /// [creatorUID] - The UID of the room creator.
  RoomInfo(this.roomName, this.token, this.url, this.loginUID, this.creatorUID);

  /// Gets the UID of the other participant in a P2P call.
  ///
  /// Returns empty string if no other participant is found.
  String getP2PToUID() {
    if (uidList.isEmpty) {
      return "";
    }
    for (var uid in uidList) {
      if (uid != loginUID) {
        return uid;
      }
    }
    return creatorUID;
  }

  /// Returns true if the current user is the room creator.
  bool isCreator() {
    return loginUID == creatorUID;
  }
}
