import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

import '../entity/const.dart';
import '../entity/video_info.dart';
import '../entity/room_info.dart';
import '../utils/logger.dart';

/// Callback type for video info changes.
typedef VideoInfoListener = void Function(VideoInfo info);

/// Manager for handling room connection and events.
///
/// This is a singleton class that manages the connection to a LiveKit room.
///
/// ## Usage
///
/// ```dart
/// // Join a room
/// final roomInfo = RoomInfo(...);
/// await TgoRTC.instance.roomManager.joinRoom(roomInfo);
///
/// // Listen to connection status
/// TgoRTC.instance.roomManager.addConnectListener((roomName, status, reason) {
///   print('Room $roomName: $status ($reason)');
/// });
///
/// // Leave the room
/// await TgoRTC.instance.roomManager.leaveRoom();
/// ```
class TgoRoomManager {
  TgoRoomManager._internal();
  static final TgoRoomManager _instance = TgoRoomManager._internal();
  static TgoRoomManager get instance => _instance;

  final List<Function(String roomName, ConnectStatus status, String reason)>
      _connectListeners = [];
  ConnectStatus _connectStatus = ConnectStatus.disconnected;
  String _connectStatusReason = '';
  String _lastRoomName = '';
  addConnectListener(
      Function(String roomName, ConnectStatus status, String reason) listener) {
    _connectListeners.add(listener);
  }

  removeConnectListener(
      Function(String roomName, ConnectStatus, String) listener) {
    _connectListeners.remove(listener);
  }

  void _setConnectStatus(String roomName, ConnectStatus status, String reason) {
    _connectStatus = status;
    _connectStatusReason = reason;
    if (roomName.isNotEmpty) {
      _lastRoomName = roomName;
    }
    for (var element in _connectListeners) {
      element(roomName, status, reason);
    }
  }

  RoomInfo? _currentRoomInfo;
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  Timer? _timeoutTimer;

  // 本地视频信息相关
  final List<VideoInfoListener> _localVideoInfoListeners = [];
  VideoInfo _currentVideoInfo = VideoInfo.empty;
  EventsListener<TrackEvent>? _videoTrackListener;

  /// 获取当前本地视频信息
  VideoInfo get currentVideoInfo => _currentVideoInfo;

  /// 添加本地视频信息监听器
  void addVideoInfoListener(VideoInfoListener listener) {
    _localVideoInfoListeners.add(listener);
    // 如果当前有有效的视频信息，立即回调
    if (_currentVideoInfo.isValid) {
      listener(_currentVideoInfo);
    }
  }

  /// 移除本地视频信息监听器
  void removeVideoInfoListener(VideoInfoListener listener) {
    _localVideoInfoListeners.remove(listener);
  }

  /// 通知所有监听器视频信息变化
  void _notifyVideoInfoChanged(VideoInfo info) {
    if (_currentVideoInfo == info) return; // 无变化则不通知
    _currentVideoInfo = info;
    Logger.info('[Video] Stats updated: $info');
    for (var listener in _localVideoInfoListeners) {
      listener(info);
    }
  }

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
  ConnectStatus get connectStatus => _connectStatus;
  String get connectStatusReason => _connectStatusReason;
  String get connectStatusRoomName => _lastRoomName;

  /// Whether this SDK currently owns a LiveKit room instance.
  ///
  /// This matches the Android SDK's `isCalling()` behavior: it is true from
  /// the beginning of [joinRoom] until [leaveRoom] releases the room, including
  /// connecting and reconnecting states. Use connect-status events when the
  /// caller specifically needs to know whether the room is connected.
  bool isCalling() => _room != null;

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
        // HarmonyOS uses ArkTS XComponent external surfaces. They are not
        // Flutter VideoTrackRenderer widgets, so LiveKit's Flutter
        // visibility tracker sees no viewKey and would pause the remote video
        // stream shortly after subscribing.
        adaptiveStream: false,
        // Dynacast: 动态暂停没有订阅者的视频层，节省带宽
        dynacast: true,
        // 部分鸿蒙设备的 Camera VideoOutput 在 4K 下 Start 成功后仍可能不出帧。
        // 原生采集器补齐首帧检测前，默认使用兼容性更好的 720p。
        defaultCameraCaptureOptions: CameraCaptureOptions(
          maxFrameRate: 30,
          params: VideoParametersPresets.h720_169,
        ),
        // 发布默认设置
        defaultVideoPublishOptions: VideoPublishOptions(
          simulcast: true, // 开启 simulcast 多层级发布
          videoCodec: 'vp8', // 编码器
          // 顶层编码与 720p 采集参数保持一致。
          videoEncoding: VideoEncoding(
            maxBitrate: 1700000,
            maxFramerate: 30,
          ),
          // LiveKit 会自动把 720p 原始画面作为顶层，这里只配置较低两层。
          videoSimulcastLayers: [
            VideoParametersPresets.h180_169,
            VideoParametersPresets.h360_169, // 640x360, 450kbps
          ],
        ),
      ),
    );
    listener = room!.createListener();
    listener!
      ..on<RoomDisconnectedEvent>((event) {
        // disconnect
        _setConnectStatus(roomInfo.roomName, ConnectStatus.disconnected,
            _disconnectReason(event.reason));
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

        _reconcileRemoteParticipants();
      })
      ..on<RoomReconnectedEvent>((event) {
        // A reconnect can restore remote participants without emitting a
        // second ParticipantConnectedEvent for each one.
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.connected, 'reconnected');
        _reconcileRemoteParticipants();
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
      })
      ..on<LocalTrackPublishedEvent>((event) {
        // 调试日志：打印本地发布的视频轨道信息
        final publication = event.publication;
        if (publication.kind == TrackType.VIDEO) {
          final track = publication.track;
          if (track is LocalVideoTrack) {
            final options = track.currentOptions;
            final dimensions = options.params.dimensions;
            Logger.info('[Video] Local track published: ${publication.sid}, '
                'resolution: ${dimensions.width}x${dimensions.height}');

            // 订阅视频统计信息事件
            _subscribeToVideoStats(track);
          }
        }
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        // 本地轨道取消发布时清理
        if (event.publication.kind == TrackType.VIDEO) {
          _unsubscribeFromVideoStats();
        }
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

  void _reconcileRemoteParticipants() {
    final currentRoom = room;
    if (currentRoom == null) return;
    for (final participant in currentRoom.remoteParticipants.values) {
      TgoRTC.instance.participantManager.setParticipantJoin(participant);
    }
  }

  String _disconnectReason(DisconnectReason? reason) {
    return reason?.toString().split('.').last ?? 'disconnected';
  }

  /// 订阅视频统计信息事件
  void _subscribeToVideoStats(LocalVideoTrack track) {
    _unsubscribeFromVideoStats(); // 先清理旧的监听
    _videoTrackListener = track.createListener();
    _videoTrackListener!.on<VideoSenderStatsEvent>((event) {
      // 获取主层级的统计信息
      final stats = event.stats;
      if (stats.isEmpty) return;

      // 获取第一个层级的信息（通常是当前活跃的层级）
      final primaryStats = stats.values.first;
      final width = primaryStats.frameWidth?.toInt() ?? 0;
      final height = primaryStats.frameHeight?.toInt() ?? 0;
      final frameRate = primaryStats.framesPerSecond?.toDouble() ?? 0.0;
      final bitrate = event.currentBitrate.toInt();

      final info = VideoInfo(
        width: width,
        height: height,
        bitrate: bitrate,
        frameRate: frameRate,
        layerId: primaryStats.rid,
        qualityLimitationReason: primaryStats.qualityLimitationReason,
      );

      _notifyVideoInfoChanged(info);
    });
  }

  /// 取消订阅视频统计信息事件
  void _unsubscribeFromVideoStats() {
    _videoTrackListener?.dispose();
    _videoTrackListener = null;
    _currentVideoInfo = VideoInfo.empty;
  }

  /// 开启超时检查定时器：未在规定时间内加入的参与者直接删除，并通过 leave 事件通知 UI
  void _startTimeoutChecker(int timeoutSeconds) {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkParticipantsTimeout(timeoutSeconds);
    });
  }

  /// 检查参与者超时：未加入且超时的直接删除并触发 leave 通知
  void _checkParticipantsTimeout(int timeoutSeconds) {
    final now = DateTime.now();
    final pending =
        TgoRTC.instance.participantManager.getPendingParticipantCreatedAt();
    for (var e in pending.entries) {
      if (now.difference(e.value).inSeconds >= timeoutSeconds) {
        TgoRTC.instance.participantManager.removeParticipantByUid(e.key);
        Logger.info('参与者 ${e.key} 超时未加入，已移除');
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
    _unsubscribeFromVideoStats();
    try {
      await room?.disconnect().timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
    } catch (e) {
      // ignore disconnect errors
    }
    if (_connectStatus != ConnectStatus.disconnected) {
      _setConnectStatus(_currentRoomInfo?.roomName ?? _lastRoomName,
          ConnectStatus.disconnected, 'clientInitiated');
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
