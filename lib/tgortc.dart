import 'entity/options.dart';
import 'manager/participant.dart';
import 'manager/room.dart';

class TgoRTC {
  TgoRTC._internal();
  static final TgoRTC _instance = TgoRTC._internal();
  static TgoRTC get instance => _instance;
  Options options = Options();
  init(Options options) {
    this.options = options;
  }

  // room manager
  RoomManager roomManager = RoomManager.instance;
  // participant manager
  ParticipantManager participantManager = ParticipantManager.instance;
}
