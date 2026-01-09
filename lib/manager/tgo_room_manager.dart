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
      roomOptions: RoomOptions(
        // AdaptiveStream: 根据视频元素尺寸自动调整订阅质量
        adaptiveStream: true,
        // Dynacast: 动态暂停没有订阅者的视频层，节省带宽
        dynacast: true,
        // 视频捕获默认设置（发布端）- 4K 最高画质
        defaultCameraCaptureOptions: const CameraCaptureOptions(
          maxFrameRate: 30,
          params: VideoParametersPresets.h2160_169, // 4K: 3840x2160
        ),
        // 发布默认设置
        defaultVideoPublishOptions: VideoPublishOptions(
          simulcast: true, // 开启 simulcast 多层级发布
          videoCodec: 'vp8', // 编码器
          // 主层级的编码参数（4K 最高质量）
          videoEncoding: const VideoEncoding(
            maxBitrate: 8000000, // 8Mbps (4K)
            maxFramerate: 30,
          ),
          // 自定义 simulcast 层级（从低到高，网络差时自动降级）
          videoSimulcastLayers: [
            VideoParametersPresets.h360_169, // 640x360, 450kbps
            VideoParametersPresets.h720_169, // 1280x720, 1.7Mbps
            VideoParametersPresets.h1080_169, // 1920x1080, 3Mbps
          ],
        ),
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
      })
      ..on<LocalTrackPublishedEvent>((event) {
        // 调试日志：打印本地发布的视频轨道信息
        final publication = event.publication;
        if (publication.kind == TrackType.VIDEO) {
          final track = publication.track;
          if (track is LocalVideoTrack) {
            final options = track.currentOptions;
            final dimensions = options.params.dimensions;
            Logger.info(
                '[Video] Local track published: ${publication.sid}, '
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
      if (participant.isJoined) {
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
    _unsubscribeFromVideoStats();
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
