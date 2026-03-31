/// Type of RTC call.
enum RTCType {
  /// Audio-only call.
  audio,

  /// Audio and video call.
  video,
}

/// Room connection status.
enum ConnectStatus {
  /// Attempting to connect to the room.
  connecting,

  /// Successfully connected to the room.
  connected,

  /// Attempting to reconnect to the room.
  reconnecting,

  /// Successfully reconnected to the room.
  reconnected,

  /// Disconnected from the room.
  disconnected,
}

/// Camera position (front or back).
enum TgoCameraPosition {
  /// Front-facing camera.
  front,

  /// Back-facing camera.
  back,
}

/// Connection quality indicator.
enum TgoConnectionQuality {
  /// Unknown connection quality.
  unknown,

  /// Excellent connection quality.
  excellent,

  /// Good connection quality.
  good,

  /// Poor connection quality.
  poor,

  /// Connection lost.
  lost,
}
