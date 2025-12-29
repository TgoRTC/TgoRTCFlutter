import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

import '../entity/const.dart';
import '../manager/tgo_audio_manager.dart';

class TgoParticipant {
  LocalParticipant? _localParticipant;
  RemoteParticipant? _remoteParticipant;
  EventsListener<ParticipantEvent>? _listener;
  final String uid;

  /// 参与者创建时间
  final DateTime _createdAt = DateTime.now();

  /// 是否已超时（未在规定时间内加入）
  bool _isTimeout = false;

  /// 获取创建时间
  DateTime get createdAt => _createdAt;

  /// 是否已超时
  bool get isTimeout => _isTimeout;

  /// 设置超时状态
  void setTimeout(bool value) {
    _isTimeout = value;
    if (value) {
      _notifyTimeout();
    }
  }

  /// 超时监听器
  final List<Function()> _timeoutListeners = [];

  /// 添加超时监听
  void addTimeoutListener(Function() listener) {
    _timeoutListeners.add(listener);
  }

  /// 移除超时监听
  void removeTimeoutListener(Function() listener) {
    _timeoutListeners.remove(listener);
  }

  /// 通知超时
  void _notifyTimeout() {
    for (var listener in _timeoutListeners) {
      listener();
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
        } else if (event.publication.source == TrackSource.microphone) {
          for (var element in _microphoneListeners) {
            element(false);
          }
        }
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        final quality = switch (event.connectionQuality) {
          ConnectionQuality.excellent => TgoConnectionQuality.excellent,
          ConnectionQuality.good => TgoConnectionQuality.good,
          ConnectionQuality.poor => TgoConnectionQuality.poor,
          ConnectionQuality.lost => TgoConnectionQuality.lost,
          _ => TgoConnectionQuality.unknown,
        };
        for (var listener in _connectionQualityListeners) {
          listener(quality);
        }
      });
  }

  bool get isJoined => _localParticipant != null || _remoteParticipant != null;
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

  setLocalParticipant(LocalParticipant participant) {
    _localParticipant = participant;
    _setupListener();
    _notifyInitialState();
  }

  setRemoteParticipant(RemoteParticipant participant) {
    _remoteParticipant = participant;
    _setupListener();
    _notifyInitialState();
    notifyJoined();
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
    final isSpeaking = _localParticipant?.isSpeaking ??
        _remoteParticipant?.isSpeaking ??
        false;
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
    _cameraPositionListeners.clear();
    _connectionQualityListeners.clear();
    _joinedListeners.clear();
    _leaveListeners.clear();
    _trackPublishedListeners.clear();
    _trackUnpublishedListeners.clear();
    _listener?.dispose();
    _listener = null;
  }
}
