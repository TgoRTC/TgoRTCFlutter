/// TgoRTC Flutter SDK
///
/// A Flutter SDK for audio and video calling based on LiveKit.
/// Provides easy-to-use APIs for room management, participant tracking, and media control.

import 'entity/options.dart';
import 'manager/tgo_audio_manager.dart';
import 'manager/tgo_participant_manager.dart';
import 'manager/tgo_room_manager.dart';

// Re-export public API classes
export 'entity/options.dart';
export 'entity/room_info.dart';
export 'entity/const.dart';
export 'entity/video_info.dart';
export 'manager/tgo_room_manager.dart' hide VideoInfoListener;
export 'manager/tgo_participant_manager.dart';
export 'manager/tgo_audio_manager.dart';
export 'participant/tgo_participant.dart';
export 'track/tgo_track_renderer.dart';
export 'pages/arkts_video_texture_layer.dart';

/// The main entry point for the TgoRTC SDK.
///
/// This is a singleton class that provides access to all SDK functionality.
///
/// ## Usage
///
/// ```dart
/// // Initialize the SDK
/// TgoRTC.instance.init(Options());
///
/// // Join a room
/// await TgoRTC.instance.roomManager.joinRoom(roomInfo);
///
/// // Get local participant
/// final local = TgoRTC.instance.participantManager.getLocalParticipant();
/// ```
class TgoRTC {
  TgoRTC._internal();
  static final TgoRTC _instance = TgoRTC._internal();

  /// Returns the singleton instance of TgoRTC.
  static TgoRTC get instance => _instance;

  /// SDK configuration options.
  Options options = Options();

  /// Initialize the SDK with the given options.
  ///
  /// Must be called before using other SDK features.
  ///
  /// [options] - Configuration options for the SDK.
  void init(Options options) {
    this.options = options;
  }

  /// Room manager for handling room connection and events.
  ///
  /// Use this to join/leave rooms and listen to room events.
  TgoRoomManager roomManager = TgoRoomManager.instance;

  /// Participant manager for handling local and remote participants.
  ///
  /// Use this to get and manage participants in the room.
  TgoParticipantManager participantManager = TgoParticipantManager.instance;

  /// Audio manager for handling audio output.
  ///
  /// Use this to switch between speaker and earpiece.
  TgoAudioManager audioManager = TgoAudioManager.instance;
}
