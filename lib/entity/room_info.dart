import 'const.dart';

class RoomInfo {
  String roomName;
  String token;
  String url;
  int maxParticipants = 2;
  RTCType rtcType = RTCType.audio;
  String loginUID;
  String creatorUID;
  bool isP2P = true;
  List<String> uidList = [];
  int timeout = 30;
  RoomInfo(this.roomName, this.token, this.url, this.loginUID, this.creatorUID);

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

  bool isCreator() {
    return loginUID == creatorUID;
  }
}
