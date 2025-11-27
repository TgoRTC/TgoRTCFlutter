import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/entity/const.dart';

class TgoLocalParticipant {
  final LocalParticipant _participant;
  EventsListener<ParticipantEvent>? _listener;

  Function(TrackSource source)? onTrackMuted;
  Function(TrackSource source)? onTrackUnmuted;
  // Function(LocalTrackPublication publication)? onTrackPublished;
  // Function(LocalTrackPublication publication)? onTrackUnpublished;

  final List<Function(bool enabled)> _microphoneListeners = [];
  final List<Function(bool enabled)> _cameraListeners = [];
  final List<Function(bool enabled)> _screenShareListeners = [];
  final List<Function(bool isSpeaking)> _speakingListeners = [];
  final List<Function(TgoCameraPosition position)> _cameraPositionListeners =
      [];
  final List<Function(TgoConnectionQuality quality)>
      _connectionQualityListeners = [];
  TgoLocalParticipant(this._participant) {
    _setupListener();
    // close
    onTrackMuted = (source) {
      if (source == TrackSource.microphone) {
        for (var element in _microphoneListeners) {
          element(false);
        }
      } else if (source == TrackSource.camera) {
        for (var element in _cameraListeners) {
          element(false);
        }
      }
    };
    // open
    onTrackUnmuted = (source) {
      if (source == TrackSource.microphone) {
        for (var element in _microphoneListeners) {
          element(true);
        }
      } else if (source == TrackSource.camera) {
        for (var element in _cameraListeners) {
          element(true);
        }
      }
    };
  }

  void _setupListener() {
    _listener = _participant.createListener();
    _listener
      ?..on<TrackMutedEvent>((event) {
        onTrackMuted?.call(event.publication.source);
      })
      ..on<TrackUnmutedEvent>((event) {
        onTrackUnmuted?.call(event.publication.source);
      })
      ..on<LocalTrackPublishedEvent>((event) {
        //  onTrackPublished?.call(event.publication);
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        //  onTrackUnpublished?.call(event.publication);
      })
      ..on<SpeakingChangedEvent>((event) {
        for (var listener in _speakingListeners) {
          listener(event.speaking);
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

  String get identity => _participant.identity;
  String get name => _participant.name;
  String? get metadata => _participant.metadata;
  bool get isSpeaking => _participant.isSpeaking;

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

  TgoCameraPosition? getCameraPosition() {
    final videoTrack = _participant.videoTrackPublications
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

  switchCamera() {
    final videoTrack = _participant.videoTrackPublications
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

  Future<LocalTrackPublication?> setCameraEnabled(bool enabled) =>
      _participant.setCameraEnabled(enabled);

  Future<LocalTrackPublication?> setMicrophoneEnabled(bool enabled) =>
      _participant.setMicrophoneEnabled(enabled);

  Future<LocalTrackPublication?> setScreenShareEnabled(bool enabled) =>
      _participant.setScreenShareEnabled(enabled);

  bool getMicrophoneEnabled() {
    return _participant.isMicrophoneEnabled();
  }

  bool getCameraEnabled() {
    return _participant.isCameraEnabled();
  }

  bool getScreenShareEnabled() {
    return _participant.isScreenShareEnabled();
  }

  void dispose() {
    _listener?.dispose();
    _listener = null;
  }
}
