import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

import '../entity/const.dart';
import '../entity/room_info.dart';
import '../utils/logger.dart';

class TgoRoomManager {
  TgoRoomManager._internal();
  static final TgoRoomManager _instance = TgoRoomManager._internal();
  static TgoRoomManager get instance => _instance;

  final List<Function(String roomName, ConnectStatus status, String reason)>
      _connectListeners = [];
  addConnectListener(
      Function(String roomName, ConnectStatus status, String reason) listener) {
    _connectListeners.add(listener);
  }

  removeConnectListener(
      Function(String roomName, ConnectStatus, String) listener) {
    _connectListeners.remove(listener);
  }

  _setConnectStatus(String roomName, ConnectStatus status, String reason) {
    for (var element in _connectListeners) {
      element(roomName, status, reason);
    }
  }

  RoomInfo? _currentRoomInfo;
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  Timer? _timeoutTimer;

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
    _setConnectStatus(
        roomInfo.roomName, ConnectStatus.connecting, "connecting");

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
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.disconnected, "disconnected");
        TgoRTC.instance.participantManager.getLocalParticipant().notifyLeave();
      })
      ..on<RoomAttemptReconnectEvent>((event) {
        // reconnect
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.connecting, "reconnecting");
      })
      ..on<RoomConnectedEvent>((event) {
        // connected
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.connected, "connected");
        TgoRTC.instance.participantManager
            .getLocalParticipant()
            .setLocalParticipant(room!.localParticipant!);
        TgoRTC.instance.participantManager.getLocalParticipant().notifyJoined();
      })
      ..on<RoomReconnectingEvent>((event) {
        // connecting
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.connecting, "connecting");
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
    // 开启定时器检查参与者超时
    _startTimeoutChecker(roomInfo.timeout);
  }

  /// 开启超时检查定时器
  void _startTimeoutChecker(int timeoutSeconds) {
    _timeoutTimer?.cancel();
    // 每秒检查一次
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkParticipantsTimeout(timeoutSeconds);
    });
  }

  /// 检查参与者是否超时
  void _checkParticipantsTimeout(int timeoutSeconds) {
    final now = DateTime.now();
    // 获取所有远程参与者（包括已超时的，用于检查是否需要取消超时）
    final participants = TgoRTC.instance.participantManager
        .getRemoteParticipants(includeTimeout: true);

    for (var participant in participants) {
      // 跳过本地参与者
      if (participant.isLocal) continue;

      // 如果已经加入（有 remoteParticipant），取消超时状态
      if (participant.hasJoined) {
        if (participant.isTimeout) {
          participant.setTimeout(false);
        }
        continue;
      }

      // 如果未加入且超过超时时间，标记为超时
      final elapsed = now.difference(participant.createdAt).inSeconds;
      if (elapsed >= timeoutSeconds && !participant.isTimeout) {
        participant.setTimeout(true);
        Logger.info('参与者 ${participant.uid} 超时未加入');
      }
    }
  }

  /// 停止超时检查
  void _stopTimeoutChecker() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  // leave room
  Future<void> leaveRoom() async {
    _stopTimeoutChecker();
    try {
      await room?.disconnect().timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
    } catch (e) {
      // ignore disconnect errors
    }
    room?.dispose();
    listener?.cancelAll();
    listener?.dispose();
    _listener = null;
    room = null;
    _currentRoomInfo = null;
    TgoRTC.instance.participantManager.clear();
  }
}
