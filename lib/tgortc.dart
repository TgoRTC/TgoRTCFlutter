import 'entity/options.dart';
import 'manager/tgo_participant_manager.dart';
import 'manager/tgo_room_manager.dart';

class TgoRTC {
  TgoRTC._internal();
  static final TgoRTC _instance = TgoRTC._internal();
  static TgoRTC get instance => _instance;
  Options options = Options();
  init(Options options) {
    this.options = options;
  }

  // room manager
  TgoRoomManager roomManager = TgoRoomManager.instance;
  // participant manager
  TgoParticipantManager participantManager = TgoParticipantManager.instance;
}
