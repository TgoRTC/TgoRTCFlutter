import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

import '../entity/const.dart';
import '../entity/video_info.dart';
import '../manager/tgo_audio_manager.dart';
import '../utils/logger.dart';

/// Dart 2.19 兼容的 firstOrNull 扩展
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Callback type for video info changes.
typedef VideoInfoListener = void Function(VideoInfo info);

/// Represents a participant in a room (local or remote).
///
/// Provides access to participant state and media controls.
///
/// ## Usage
///
/// ```dart
/// // Get the local participant
/// final local = TgoRTC.instance.participantManager.getLocalParticipant();
///
/// // Listen to microphone state changes
/// local.addMicrophoneStatusListener((enabled) {
///   print('Microphone: $enabled');
/// });
///
/// // Control media (local participant only)
/// await local.setCameraEnabled(true);
/// await local.setMicrophoneEnabled(true);
///
/// // Listen to join/leave events
/// local.addJoinedListener(() => print('Joined'));
/// local.addLeaveListener(() => print('Left'));
/// ```
class TgoParticipant {
  LocalParticipant? _localParticipant;
  RemoteParticipant? _remoteParticipant;
  EventsListener<ParticipantEvent>? _listener;
  final String uid;

  // 视频信息相关
  final List<VideoInfoListener> _videoInfoListeners = [];
  VideoInfo _currentVideoInfo = VideoInfo.empty;
  EventsListener<TrackEvent>? _videoTrackListener;

  /// 获取当前视频信息
  VideoInfo get currentVideoInfo => _currentVideoInfo;

  /// 添加视频信息监听器
  void addVideoInfoListener(VideoInfoListener listener) {
    _videoInfoListeners.add(listener);
    // 如果当前有有效的视频信息，立即回调
    if (_currentVideoInfo.isValid) {
      listener(_currentVideoInfo);
    }
  }

  /// 移除视频信息监听器
  void removeVideoInfoListener(VideoInfoListener listener) {
    _videoInfoListeners.remove(listener);
  }

  /// 通知所有监听器视频信息变化
  void _notifyVideoInfoChanged(VideoInfo info) {
    if (_currentVideoInfo == info) return; // 无变化则不通知
    _currentVideoInfo = info;
    Logger.info('[Video] $uid stats updated: $info');
    for (var listener in _videoInfoListeners) {
      listener(info);
    }
  }

  TgoParticipant(this.uid, this._localParticipant, this._remoteParticipant) {
    _setupListener();
  }

  VideoTrack? getVideoTrack({TrackSource source = TrackSource.camera}) {
    if (_localParticipant != null) {
      return _localParticipant!.videoTrackPublications
          .where((pub) => pub.source == source)
          .firstOrNull
          ?.track as VideoTrack?;
    }
    if (_remoteParticipant != null) {
      return _remoteParticipant!.videoTrackPublications
          .where((pub) => pub.source == source)
          .firstOrNull
          ?.track as VideoTrack?;
    }
    return null;
  }

  bool get isLocal =>
      uid == TgoRTC.instance.roomManager.currentRoomInfo?.loginUID;

  final List<Function(bool enabled)> _microphoneListeners = [];
  final List<Function(bool enabled)> _cameraListeners = [];
  final List<Function(bool enabled)> _speakerListeners = [];
  final List<Function(bool enabled)> _screenShareListeners = [];
  final List<Function(bool isSpeaking)> _speakingListeners = [];
  final List<Function(bool available, bool muted)> _videoTrackListeners = [];
  // local only
  final List<Function(TgoCameraPosition position)> _cameraPositionListeners =
      [];
  final List<Function(TgoConnectionQuality quality)>
      _connectionQualityListeners = [];
  final List<Function()> _joinedListeners = [];
  final List<Function()> _leaveListeners = [];
  final List<Function()> _trackPublishedListeners = [];
  final List<Function()> _trackUnpublishedListeners = [];

  addTrackPublishedListener(Function() listener) {
    _trackPublishedListeners.add(listener);
  }

  removeTrackPublishedListener(Function() listener) {
    _trackPublishedListeners.remove(listener);
  }

  addTrackUnpublishedListener(Function() listener) {
    _trackUnpublishedListeners.add(listener);
  }

  removeTrackUnpublishedListener(Function() listener) {
    _trackUnpublishedListeners.remove(listener);
  }

  addMicrophoneStatusListener(Function(bool enabled) listener) {
    _microphoneListeners.add(listener);
  }

  removeMicrophoneStatusListener(Function(bool enabled) listener) {
    _microphoneListeners.remove(listener);
  }

  addCameraStatusListener(Function(bool enabled) listener) {
    _cameraListeners.add(listener);
  }

  removeCameraStatusListener(Function(bool enabled) listener) {
    _cameraListeners.remove(listener);
  }

  addSpeakerStatusListener(Function(bool enabled) listener) {
    _speakerListeners.add(listener);
  }

  removeSpeakerStatusListener(Function(bool enabled) listener) {
    _speakerListeners.remove(listener);
  }

  addScreenShareStatusListener(Function(bool enabled) listener) {
    _screenShareListeners.add(listener);
  }

  removeScreenShareStatusListener(Function(bool enabled) listener) {
    _screenShareListeners.remove(listener);
  }

  addSpeakingListener(Function(bool isSpeaking) listener) {
    _speakingListeners.add(listener);
  }

  removeSpeakingListener(Function(bool isSpeaking) listener) {
    _speakingListeners.remove(listener);
  }

  /// Receives camera track availability and mute changes.
  void addVideoTrackListener(Function(bool available, bool muted) listener) {
    _videoTrackListeners.add(listener);
  }

  void removeVideoTrackListener(Function(bool available, bool muted) listener) {
    _videoTrackListeners.remove(listener);
  }

  void _notifyVideoTrackChanged(bool available, bool muted) {
    for (final listener in _videoTrackListeners.toList()) {
      listener(available, muted);
    }
  }

  addCameraPositionListener(Function(TgoCameraPosition position) listener) {
    _cameraPositionListeners.add(listener);
  }

  removeCameraPositionListener(Function(TgoCameraPosition position) listener) {
    _cameraPositionListeners.remove(listener);
  }

  addConnQualityListener(Function(TgoConnectionQuality quality) listener) {
    _connectionQualityListeners.add(listener);
  }

  removeConnQualityListener(Function(TgoConnectionQuality quality) listener) {
    _connectionQualityListeners.remove(listener);
  }

  addJoinedListener(Function() listener) {
    _joinedListeners.add(listener);
  }

  removeJoinedListener(Function() listener) {
    _joinedListeners.remove(listener);
  }

  addLeaveListener(Function() listener) {
    _leaveListeners.add(listener);
  }

  removeLeaveListener(Function() listener) {
    _leaveListeners.remove(listener);
  }

  void _setupListener() {
    if (_localParticipant != null) {
      _listener = _localParticipant?.createListener();
    }
    if (_remoteParticipant != null) {
      _listener = _remoteParticipant?.createListener();
    }
    if (_listener == null) {
      return;
    }
    _listener!
      ..on<TrackMutedEvent>((event) {
        if (event.publication.source == TrackSource.microphone) {
          for (var element in _microphoneListeners) {
            element(false);
          }
        } else if (event.publication.source == TrackSource.camera) {
          for (var element in _cameraListeners) {
            element(false);
          }
          _notifyVideoTrackChanged(true, true);
        }
      })
      ..on<TrackUnmutedEvent>((event) {
        if (event.publication.source == TrackSource.microphone) {
          for (var element in _microphoneListeners) {
            element(true);
          }
        } else if (event.publication.source == TrackSource.camera) {
          for (var element in _cameraListeners) {
            element(true);
          }
          _notifyVideoTrackChanged(true, false);
        }
      })
      ..on<SpeakingChangedEvent>((event) {
        for (var listener in _speakingListeners) {
          listener(event.speaking);
        }
      })
      ..on<TrackSubscribedEvent>((event) {
        if (event.publication.source == TrackSource.camera) {
          for (var element in _cameraListeners) {
            element(true);
          }
          _notifyVideoTrackChanged(true, false);
          // 订阅远程视频统计信息
          final track = event.track;
          if (track is RemoteVideoTrack) {
            _subscribeToVideoStats(track);
          }
        } else if (event.publication.source == TrackSource.microphone) {
          for (var element in _microphoneListeners) {
            element(true);
          }
        }
      })
      ..on<LocalTrackPublishedEvent>((event) {
        if (event.publication.source == TrackSource.camera) {
          for (var element in _cameraListeners) {
            element(true);
          }
          _notifyVideoTrackChanged(true, false);
          // 订阅本地视频统计信息
          final track = event.publication.track;
          if (track is LocalVideoTrack) {
            _subscribeToLocalVideoStats(track);
          }
        } else if (event.publication.source == TrackSource.microphone) {
          for (var element in _microphoneListeners) {
            element(true);
          }
        }
        for (var element in _trackPublishedListeners) {
          element();
        }
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        if (event.publication.source == TrackSource.camera) {
          for (var element in _cameraListeners) {
            element(false);
          }
          _notifyVideoTrackChanged(false, false);
          // 取消订阅视频统计信息
          _unsubscribeFromVideoStats();
        } else if (event.publication.source == TrackSource.microphone) {
          for (var element in _microphoneListeners) {
            element(false);
          }
        }
        for (var element in _trackUnpublishedListeners) {
          element();
        }
      })
      ..on<TrackPublishedEvent>((event) {
        if (event.publication.source == TrackSource.camera) {
          for (var element in _cameraListeners) {
            element(true);
          }
          _notifyVideoTrackChanged(true, false);
        } else if (event.publication.source == TrackSource.microphone) {
          for (var element in _microphoneListeners) {
            element(true);
          }
        }
        for (var element in _trackPublishedListeners) {
          element();
        }
      })
      ..on<TrackUnpublishedEvent>((event) {
        if (event.publication.source == TrackSource.camera) {
          for (var element in _cameraListeners) {
            element(false);
          }
          _notifyVideoTrackChanged(false, false);
        } else if (event.publication.source == TrackSource.microphone) {
          for (var element in _microphoneListeners) {
            element(false);
          }
        }
        for (var element in _trackUnpublishedListeners) {
          element();
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.publication.source == TrackSource.camera) {
          for (var element in _cameraListeners) {
            element(false);
          }
          _notifyVideoTrackChanged(false, false);
          // 取消订阅视频统计信息
          _unsubscribeFromVideoStats();
        } else if (event.publication.source == TrackSource.microphone) {
          for (var element in _microphoneListeners) {
            element(false);
          }
        }
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        TgoConnectionQuality quality;
        switch (event.connectionQuality) {
          case ConnectionQuality.excellent:
            quality = TgoConnectionQuality.excellent;
            break;
          case ConnectionQuality.good:
            quality = TgoConnectionQuality.good;
            break;
          case ConnectionQuality.poor:
            quality = TgoConnectionQuality.poor;
            break;
          case ConnectionQuality.lost:
            quality = TgoConnectionQuality.lost;
            break;
          default:
            quality = TgoConnectionQuality.unknown;
        }
        for (var listener in _connectionQualityListeners) {
          listener(quality);
        }
      });
  }

  /// 订阅本地视频统计信息事件
  void _subscribeToLocalVideoStats(LocalVideoTrack track) {
    _unsubscribeFromVideoStats(); // 先清理旧的监听
    _videoTrackListener = track.createListener();
    _videoTrackListener!.on<VideoSenderStatsEvent>((event) {
      final stats = event.stats;
      if (stats.isEmpty) return;

      // 获取第一个层级的信息
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

  /// 订阅远程视频统计信息事件
  void _subscribeToVideoStats(RemoteVideoTrack track) {
    _unsubscribeFromVideoStats(); // 先清理旧的监听
    _videoTrackListener = track.createListener();
    _videoTrackListener!.on<VideoReceiverStatsEvent>((event) {
      final stats = event.stats;
      final width = stats.frameWidth?.toInt() ?? 0;
      final height = stats.frameHeight?.toInt() ?? 0;
      final frameRate = stats.framesPerSecond?.toDouble() ?? 0.0;
      final bitrate = event.currentBitrate.toInt();

      final info = VideoInfo(
        width: width,
        height: height,
        bitrate: bitrate,
        frameRate: frameRate,
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

  bool get isJoined => _localParticipant != null || _remoteParticipant != null;

  bool get isSpeaking =>
      _localParticipant?.isSpeaking ?? _remoteParticipant?.isSpeaking ?? false;

  double get audioLevel =>
      _localParticipant?.audioLevel ?? _remoteParticipant?.audioLevel ?? 0;
  // local only
  TgoCameraPosition? getCameraPosition() {
    if (_localParticipant == null) return null;
    final videoTrack = _localParticipant!.videoTrackPublications
        .where((pub) => pub.source == TrackSource.camera)
        .firstOrNull
        ?.track;
    if (videoTrack != null) {
      final options = videoTrack.currentOptions;
      if (options is CameraCaptureOptions) {
        if (options.cameraPosition == CameraPosition.front) {
          return TgoCameraPosition.front;
        } else {
          return TgoCameraPosition.back;
        }
      }
    }
    return null;
  }

  // local only
  switchCamera() {
    if (_localParticipant == null) return;
    final videoTrack = _localParticipant!.videoTrackPublications
        .where((pub) => pub.source == TrackSource.camera)
        .firstOrNull
        ?.track;
    if (videoTrack != null) {
      final options = videoTrack.currentOptions;
      if (options is CameraCaptureOptions) {
        final newPosition = options.cameraPosition == CameraPosition.front
            ? CameraPosition.back
            : CameraPosition.front;
        videoTrack.setCameraPosition(newPosition).then((_) {
          for (var listener in _cameraPositionListeners) {
            if (newPosition == CameraPosition.front) {
              listener(TgoCameraPosition.front);
            } else {
              listener(TgoCameraPosition.back);
            }
          }
        });
      }
    }
  }

  // local only
  Future<void> setCameraEnabled(bool enabled) async {
    if (_localParticipant == null) return;
    await _localParticipant!.setCameraEnabled(enabled);
  }

  // local only
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_localParticipant == null) return;
    await _localParticipant!.setMicrophoneEnabled(enabled);
  }

  // local only
  Future<void> setScreenShareEnabled(bool enabled) async {
    if (_localParticipant == null) return;
    await _localParticipant!.setScreenShareEnabled(enabled);
  }

  // local only
  bool getMicrophoneEnabled() {
    return _localParticipant?.isMicrophoneEnabled() ??
        _remoteParticipant?.isMicrophoneEnabled() ??
        false;
  }

  // local only
  bool getCameraEnabled() {
    return _localParticipant?.isCameraEnabled() ??
        _remoteParticipant?.isCameraEnabled() ??
        false;
  }

  // local only
  bool getScreenShareEnabled() {
    return _localParticipant?.isScreenShareEnabled() ??
        _remoteParticipant?.isScreenShareEnabled() ??
        false;
  }

  // local only
  Future<void> toggleSpeakerphone() async {
    if (_localParticipant == null) return;
    await TgoAudioManager.instance.toggleSpeakerphone();
    for (var listener in _speakerListeners) {
      listener(TgoAudioManager.instance.isSpeakerOn);
    }
  }

  // local only
  Future<void> setSpeakerphoneOn(bool on,
      {bool forceSpeakerOutput = false}) async {
    if (_localParticipant == null) return;
    await TgoAudioManager.instance
        .setSpeakerphoneOn(on, forceSpeakerOutput: forceSpeakerOutput);
    for (var listener in _speakerListeners) {
      listener(on);
    }
  }

  // local only
  bool getSpeakerEnabled() {
    if (_localParticipant == null) return false;
    return TgoAudioManager.instance.isSpeakerOn;
  }

  /// Binds the LiveKit local participant exactly once per instance.
  ///
  /// [TgoParticipantManager.getLocalParticipant] is also used while building
  /// participant snapshots. Rebinding the same instance from that hot path
  /// would synchronously emit the initial media state again, which can cause
  /// event listeners to re-enter participant snapshot generation.
  void setLocalParticipant(LocalParticipant participant) {
    if (identical(_localParticipant, participant)) {
      return;
    }

    _disposeParticipantListener();
    _unsubscribeFromVideoStats();
    _localParticipant = participant;
    _setupListener();
    _notifyInitialState();
  }

  /// Replaces the remote participant listener only when LiveKit supplies a
  /// different participant instance.
  void setRemoteParticipant(RemoteParticipant participant) {
    if (identical(_remoteParticipant, participant)) {
      return;
    }

    _disposeParticipantListener();
    _unsubscribeFromVideoStats();
    _remoteParticipant = participant;
    _setupListener();
    _notifyInitialState();
    notifyJoined();
  }

  void _disposeParticipantListener() {
    _listener?.dispose();
    _listener = null;
  }

  void _notifyInitialState() {
    // 通知麦克风状态
    final micEnabled = _localParticipant?.isMicrophoneEnabled() ??
        _remoteParticipant?.isMicrophoneEnabled() ??
        false;
    for (var listener in _microphoneListeners) {
      listener(micEnabled);
    }

    // 通知摄像头状态
    final cameraEnabled = _localParticipant?.isCameraEnabled() ??
        _remoteParticipant?.isCameraEnabled() ??
        false;
    for (var listener in _cameraListeners) {
      listener(cameraEnabled);
    }

    // 通知说话状态
    final isSpeaking = this.isSpeaking;
    for (var listener in _speakingListeners) {
      listener(isSpeaking);
    }
  }

  notifyJoined() {
    for (var element in _joinedListeners) {
      element();
    }
  }

  notifyLeave() {
    for (var element in _leaveListeners) {
      element();
    }
    dispose();
  }

  void dispose() {
    _microphoneListeners.clear();
    _cameraListeners.clear();
    _speakerListeners.clear();
    _screenShareListeners.clear();
    _speakingListeners.clear();
    _videoTrackListeners.clear();
    _cameraPositionListeners.clear();
    _connectionQualityListeners.clear();
    _joinedListeners.clear();
    _leaveListeners.clear();
    _trackPublishedListeners.clear();
    _trackUnpublishedListeners.clear();
    _videoInfoListeners.clear();
    _unsubscribeFromVideoStats();
    _disposeParticipantListener();
  }
}
