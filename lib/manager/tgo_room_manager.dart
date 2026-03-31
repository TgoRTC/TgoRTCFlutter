import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

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
      bool? screenShareEnabled,
      bool? scrennShareEnabled}) async {
    if (_currentRoomInfo != null) {
      Logger.error("already in room");
      return;
    }
    final enableScreenShare = screenShareEnabled ?? scrennShareEnabled ?? false;
    final connectStopwatch = Stopwatch()..start();
    Logger.info(
      '[Room] joinRoom start room=${roomInfo.roomName} url=${roomInfo.url} '
      'loginUID=${roomInfo.loginUID} rtcType=${roomInfo.rtcType} '
      'uids=${roomInfo.uidList} mic=$micEnabled camera=$cameraEnabled '
      'screen=$enableScreenShare timeout=${roomInfo.timeout}',
    );
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
        Logger.info(
          '[RoomEvent] disconnected room=${roomInfo.roomName} '
          'reason=${event.reason} remoteParticipants=${room?.remoteParticipants.length}',
        );
        // disconnect
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.disconnected, "disconnected");
        TgoRTC.instance.participantManager.getLocalParticipant()?.notifyLeave();
      })
      ..on<RoomAttemptReconnectEvent>((event) {
        Logger.info('[RoomEvent] attemptReconnect room=${roomInfo.roomName}');
        // reconnect
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.reconnecting, "reconnecting");
      })
      ..on<RoomConnectedEvent>((event) {
        Logger.info(
          '[RoomEvent] connected room=${roomInfo.roomName} '
          'local=${room?.localParticipant?.identity} '
          'remoteParticipants=${room?.remoteParticipants.length} '
          'elapsedMs=${connectStopwatch.elapsedMilliseconds}',
        );
        // connected
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.connected, "connected");
        TgoRTC.instance.participantManager
            .getLocalParticipant()
            ?.setLocalParticipant(room!.localParticipant!);
        TgoRTC.instance.participantManager.getLocalParticipant()?.notifyJoined();
        for (final participant in room!.remoteParticipants.values) {
          TgoRTC.instance.participantManager.setParticipantJoin(participant);
        }
      })
      ..on<RoomReconnectingEvent>((event) {
        Logger.info('[RoomEvent] reconnecting room=${roomInfo.roomName}');
        // reconnecting
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.reconnecting, "reconnecting");
      })
      ..on<RoomReconnectedEvent>((event) {
        Logger.info(
          '[RoomEvent] reconnected room=${roomInfo.roomName} '
          'local=${room?.localParticipant?.identity} '
          'remoteParticipants=${room?.remoteParticipants.length}',
        );
        _setConnectStatus(
            roomInfo.roomName, ConnectStatus.reconnected, "reconnected");
        TgoRTC.instance.participantManager
            .getLocalParticipant()
            ?.setLocalParticipant(room!.localParticipant!);
        TgoRTC.instance.participantManager.getLocalParticipant()?.notifyJoined();
      })
      ..on<ParticipantConnectedEvent>((event) {
        Logger.info(
          '[RoomEvent] participantConnected uid=${event.participant.identity} '
          'sid=${event.participant.sid} '
          'connectionQuality=${event.participant.connectionQuality} '
          'remoteCount=${room?.remoteParticipants.length}',
        );
        // remote join
        TgoRTC.instance.participantManager
            .setParticipantJoin(event.participant);
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        Logger.info(
          '[RoomEvent] participantDisconnected uid=${event.participant.identity} '
          'sid=${event.participant.sid} '
          'remoteCount=${room?.remoteParticipants.length}',
        );
        // remote leave
        TgoRTC.instance.participantManager
            .setParticipantLeave(event.participant);
      })
      ..on<LocalTrackPublishedEvent>((event) {
        Logger.info(
          '[RoomEvent] localTrackPublished kind=${event.publication.kind} '
          'source=${event.publication.source} sid=${event.publication.sid} '
          'track=${event.publication.track?.sid}',
        );
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
        Logger.info(
          '[RoomEvent] localTrackUnpublished kind=${event.publication.kind} '
          'source=${event.publication.source} sid=${event.publication.sid}',
        );
        // 本地轨道取消发布时清理
        if (event.publication.kind == TrackType.VIDEO) {
          _unsubscribeFromVideoStats();
        }
      });
    Logger.info(
      '[Room] connect begin room=${roomInfo.roomName} '
      'url=${roomInfo.url} tokenLength=${roomInfo.token.length}',
    );
    try {
      await room!.connect(
        roomInfo.url,
        roomInfo.token,
      );
      Logger.info(
        '[Room] connect success room=${roomInfo.roomName} '
        'local=${room?.localParticipant?.identity} '
        'remoteParticipants=${room?.remoteParticipants.length} '
        'elapsedMs=${connectStopwatch.elapsedMilliseconds}',
      );
    } catch (e, s) {
      Logger.error(
        '[Room] connect failed room=${roomInfo.roomName} '
        'url=${roomInfo.url} elapsedMs=${connectStopwatch.elapsedMilliseconds} '
        'errorType=${e.runtimeType} error=$e',
      );
      Logger.error('[Room] connect failed stack=$s');
      rethrow;
    } finally {
      connectStopwatch.stop();
    }

    if (cameraEnabled) {
      Logger.info('[Room] enable camera begin room=${roomInfo.roomName}');
      await room!.localParticipant?.setCameraEnabled(true);
      Logger.info('[Room] enable camera done room=${roomInfo.roomName}');
    }
    if (cameraEnabled || enableScreenShare) {
      Logger.info(
        '[Room] wait after video publish room=${roomInfo.roomName} '
        'camera=$cameraEnabled screen=$enableScreenShare',
      );
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (micEnabled) {
      Logger.info('[Room] enable microphone begin room=${roomInfo.roomName}');
      await room!.localParticipant?.setMicrophoneEnabled(true);
      Logger.info('[Room] enable microphone done room=${roomInfo.roomName}');
    }
    if (enableScreenShare) {
      Logger.info('[Room] enable screen share begin room=${roomInfo.roomName}');
      await Future.delayed(const Duration(milliseconds: 300));
      await room!.localParticipant?.setScreenShareEnabled(true);
      Logger.info('[Room] enable screen share done room=${roomInfo.roomName}');
    }

    // 开启定时器检查参与者超时
    Logger.info(
      '[Room] start timeout checker room=${roomInfo.roomName} '
      'timeout=${roomInfo.timeout}',
    );
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
    final pending = TgoRTC.instance.participantManager
        .getPendingParticipantCreatedAt();
    if (pending.isNotEmpty) {
      Logger.info(
        '[Room] timeout check pending=${pending.keys.toList()} '
        'timeoutSeconds=$timeoutSeconds',
      );
    }
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
    Logger.info(
      '[Room] leaveRoom start room=${_currentRoomInfo?.roomName} '
      'local=${room?.localParticipant?.identity} '
      'remoteParticipants=${room?.remoteParticipants.length}',
    );
    _stopTimeoutChecker();
    _unsubscribeFromVideoStats();
    try {
      await room?.disconnect().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              Logger.error('[Room] disconnect timeout room=${_currentRoomInfo?.roomName}');
              return null;
            },
          );
      Logger.info('[Room] disconnect finished room=${_currentRoomInfo?.roomName}');
    } catch (e) {
      Logger.error('[Room] disconnect failed room=${_currentRoomInfo?.roomName} error=$e');
    }
    room?.dispose();
    listener?.cancelAll();
    listener?.dispose();
    _listener = null;
    room = null;
    _currentRoomInfo = null;
    TgoRTC.instance.participantManager.clear();
    Logger.info('[Room] leaveRoom done');
  }
}
