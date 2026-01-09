/// Video stream information (for both local and remote streams).
///
/// Contains resolution, bitrate, frame rate, and quality information.
class VideoInfo {
  /// Video width in pixels.
  final int width;

  /// Video height in pixels.
  final int height;

  /// Current bitrate in bits per second (bps).
  final int bitrate;

  /// Current frame rate.
  final double frameRate;

  /// Current layer identifier (e.g., "f", "h", "q" for full, half, quarter).
  final String? layerId;

  /// Quality limitation reason (bandwidth, cpu, other, none).
  final String? qualityLimitationReason;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.bitrate,
    required this.frameRate,
    this.layerId,
    this.qualityLimitationReason,
  });

  /// Empty video info instance.
  static const empty = VideoInfo(
    width: 0,
    height: 0,
    bitrate: 0,
    frameRate: 0,
  );

  /// Returns true if the video info contains valid data.
  bool get isValid => width > 0 && height > 0;

  /// Returns formatted resolution string (e.g., "1920x1080").
  String get resolutionString => '${width}x$height';

  /// Returns formatted bitrate string (Kbps or Mbps).
  String get bitrateString {
    if (bitrate >= 1000000) {
      return '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';
    } else if (bitrate >= 1000) {
      return '${(bitrate / 1000).toStringAsFixed(0)} Kbps';
    }
    return '$bitrate bps';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoInfo &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height &&
          bitrate == other.bitrate &&
          frameRate == other.frameRate &&
          layerId == other.layerId;

  @override
  int get hashCode =>
      width.hashCode ^
      height.hashCode ^
      bitrate.hashCode ^
      frameRate.hashCode ^
      layerId.hashCode;

  @override
  String toString() {
    return 'VideoInfo(resolution: $resolutionString, bitrate: $bitrateString, fps: ${frameRate.toStringAsFixed(1)}, layer: $layerId)';
  }
}
