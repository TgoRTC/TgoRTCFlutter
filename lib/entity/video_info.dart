/// 视频流信息（本地和远程通用）
class VideoInfo {
  /// 视频宽度
  final int width;

  /// 视频高度
  final int height;

  /// 当前比特率 (bps)
  final int bitrate;

  /// 帧率
  final double frameRate;

  /// 当前层级标识 (如 "f", "h", "q" 分别代表 full, half, quarter)
  final String? layerId;

  /// 质量限制原因 (bandwidth, cpu, other, none)
  final String? qualityLimitationReason;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.bitrate,
    required this.frameRate,
    this.layerId,
    this.qualityLimitationReason,
  });

  /// 空的视频信息
  static const empty = VideoInfo(
    width: 0,
    height: 0,
    bitrate: 0,
    frameRate: 0,
  );

  /// 是否有效
  bool get isValid => width > 0 && height > 0;

  /// 格式化的分辨率字符串
  String get resolutionString => '${width}x$height';

  /// 格式化的比特率字符串 (Kbps 或 Mbps)
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

