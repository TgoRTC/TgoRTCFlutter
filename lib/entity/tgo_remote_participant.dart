import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/entity/const.dart';

class TgoRemoteParticipant {
  final String uid;
  RemoteParticipant? _participant;
  EventsListener<ParticipantEvent>? _listener;
  final List<Function(bool enabled)> _microphoneListeners = [];
  final List<Function(bool enabled)> _cameraListeners = [];
  final List<Function(bool isSpeaking)> _speakingListeners = [];
  final List<Function(TgoConnectionQuality quality)>
      _connectionQualityListeners = [];
  final List<Function()> _joinedListeners = [];
  final List<Function()> _leaveListeners = [];
  TgoRemoteParticipant(this.uid, this._participant) {
    _setupListener();
  }
  void _setupListener() {
    if (_participant == null) {
      return;
    }
    _listener = _participant!.createListener();
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

  addConnQualityListener(Function(TgoConnectionQuality quality) listener) {
    _connectionQualityListeners.add(listener);
  }

  removeConnQualityListener(Function(TgoConnectionQuality quality) listener) {
    _connectionQualityListeners.remove(listener);
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

  setParticipant(RemoteParticipant participant) {
    _participant = participant;
    for (var element in _joinedListeners) {
      element();
    }
    _setupListener();
  }

  setLeave() {
    _listener?.dispose();
    _listener = null;
    _participant = null;
    for (var element in _leaveListeners) {
      element();
    }
  }
}
