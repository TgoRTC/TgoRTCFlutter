import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

import '../entity/const.dart';
import '../entity/room_info.dart';
import '../utils/logger.dart';

class TgoRoomManager {
  TgoRoomManager._internal();
  static final TgoRoomManager _instance = TgoRoomManager._internal();
  static TgoRoomManager get instance => _instance;

  final List<Function(ConnectStatus status, String reason)> _connectListeners =
      [];
  addConnectListener(Function(ConnectStatus status, String reason) listener) {
    _connectListeners.add(listener);
  }

  removeConnectListener(Function(ConnectStatus, String) listener) {
    _connectListeners.remove(listener);
  }

  _setConnectStatus(ConnectStatus status, String reason) {
    for (var element in _connectListeners) {
      element(status, reason);
    }
  }

  RoomInfo? _currentRoomInfo;
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  Room? get room => _room;
  set room(Room? value) {
    if (_room != null && value != null) {
      Logger.error("room already exists, cannot reassign");
      return;
    }
    _room = value;
  }

  EventsListener<RoomEvent>? get listener => _listener;
  set listener(EventsListener<RoomEvent>? value) {
    if (_listener != null && value != null) {
      Logger.error("listener already exists, cannot reassign");
      return;
    }
    _listener = value;
  }

  RoomInfo? get currentRoomInfo => _currentRoomInfo;

  // join room
  joinRoom(RoomInfo roomInfo,
      {micEnabled = false,
      cameraEnabled = false,
      scrennShareEnabled = false}) async {
    if (_currentRoomInfo != null) {
      Logger.error("already in room");
      return;
    }
    _currentRoomInfo = roomInfo;
    _setConnectStatus(ConnectStatus.connecting, "connecting");

    room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    listener = room!.createListener();
    listener!
      ..on<RoomDisconnectedEvent>((event) {
        // disconnect
        _setConnectStatus(ConnectStatus.disconnected, "disconnected");
        TgoRTC.instance.participantManager.getLocalParticipant().notifyLeave();
      })
      ..on<RoomAttemptReconnectEvent>((event) {
        // reconnect
        _setConnectStatus(ConnectStatus.connecting, "reconnecting");
      })
      ..on<RoomConnectedEvent>((event) {
        // connected
        _setConnectStatus(ConnectStatus.connected, "connected");
        TgoRTC.instance.participantManager
            .getLocalParticipant()
            .setLocalParticipant(room!.localParticipant!);
        TgoRTC.instance.participantManager.getLocalParticipant().notifyJoined();
      })
      ..on<RoomReconnectingEvent>((event) {
        // connecting
        _setConnectStatus(ConnectStatus.connecting, "connecting");
      })
      ..on<ParticipantConnectedEvent>((event) {
        // remote join
        TgoRTC.instance.participantManager
            .setParticipantJoin(event.participant);
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        // remote leave
        TgoRTC.instance.participantManager
            .setParticipantLeave(event.participant);
      });
    await room!.connect(
      roomInfo.url,
      roomInfo.token,
      fastConnectOptions: FastConnectOptions(
        microphone: TrackOption(enabled: micEnabled),
        camera: TrackOption(enabled: cameraEnabled),
        screen: TrackOption(enabled: scrennShareEnabled),
      ),
    );
  }

  // leave room
  leaveRoom() {
    room?.disconnect();
    room?.dispose();
    listener?.cancelAll();
    listener?.dispose();
    _listener = null;
    room = null;
    _currentRoomInfo = null;
    TgoRTC.instance.participantManager.clear();
  }
}
