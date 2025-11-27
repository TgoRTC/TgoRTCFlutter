import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

class TgoTrackRenderer {
  final VideoTrack _videoTrack;
  final RTCVideoViewObjectFit fit;

  TgoTrackRenderer(
    this._videoTrack, {
    this.fit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  });

  /// 返回可渲染的 Widget
  Widget build() {
    return VideoTrackRenderer(
      _videoTrack,
      fit: fit,
      mirrorMode: TgoRTC.instance.options.mirror
          ? VideoViewMirrorMode.mirror
          : VideoViewMirrorMode.off,
    );
  }
}
