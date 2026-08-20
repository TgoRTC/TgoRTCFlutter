import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

import '../utils/logger.dart';

/// Manager for handling audio output and device changes.
///
/// This is a singleton class that provides audio control functionality
/// such as switching between speaker and earpiece.
///
/// ## Usage
///
/// ```dart
/// // Switch to speaker
/// await TgoRTC.instance.audioManager.setSpeakerphoneOn(true);
///
/// // Toggle speaker
/// await TgoRTC.instance.audioManager.toggleSpeakerphone();
///
/// // Check if speaker is on
/// final isSpeakerOn = TgoRTC.instance.audioManager.isSpeakerOn;
/// ```
class TgoAudioManager {
  TgoAudioManager._internal() {
    _initDeviceListener();
  }
  static final TgoAudioManager _instance = TgoAudioManager._internal();
  static TgoAudioManager get instance => _instance;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  final List<Function(List<MediaDevice>)> _deviceChangeListeners = [];
  StreamSubscription? _deviceChangeSubscription;

  /// 初始化设备变化监听
  void _initDeviceListener() {
    _deviceChangeSubscription =
        Hardware.instance.onDeviceChange.stream.listen((devices) {
      for (var listener in _deviceChangeListeners) {
        listener(devices);
      }
    });
  }

  /// 添加设备变化监听
  void addDeviceChangeListener(Function(List<MediaDevice>) listener) {
    _deviceChangeListeners.add(listener);
  }

  /// 移除设备变化监听
  void removeDeviceChangeListener(Function(List<MediaDevice>) listener) {
    _deviceChangeListeners.remove(listener);
  }

  /// 切换扬声器/听筒
  /// - [on]: true 使用扬声器，false 使用耳机（如果连接）或听筒
  /// - [forceSpeakerOutput]: 仅 iOS 有效，如果为 true，即使连接了耳机/蓝牙也强制使用扬声器
  Future<void> setSpeakerphoneOn(bool on,
      {bool forceSpeakerOutput = false}) async {
    // LiveKit 当前只在 iOS 分支调用 flutter_webrtc，HarmonyOS
    // 需要直接调用底层音频路由，否则会记录成功但实际不切换设备。
    if (lkPlatformIs(PlatformType.ohos)) {
      Logger.info('[AudioRoute] setSpeakerphoneOn=$on platform=ohos');
      await rtc.Helper.setSpeakerphoneOn(on);
    } else {
      await Hardware.instance.setSpeakerphoneOn(on);
    }
    _isSpeakerOn = on;
  }

  /// 切换扬声器状态
  Future<void> toggleSpeakerphone() async {
    await setSpeakerphoneOn(!_isSpeakerOn);
  }

  /// 是否可以切换扬声器
  bool get canSwitchSpeakerphone => lkPlatformIs(PlatformType.ohos)
      ? true
      : Hardware.instance.canSwitchSpeakerphone;

  /// 当前是否使用扬声器
  bool? get speakerOn => lkPlatformIs(PlatformType.ohos)
      ? _isSpeakerOn
      : Hardware.instance.speakerOn;

  /// 获取音频输入设备列表（麦克风）
  Future<List<MediaDevice>> getAudioInputDevices() async {
    return await Hardware.instance.enumerateDevices(type: 'audioinput');
  }

  /// 获取音频输出设备列表（扬声器/耳机）
  Future<List<MediaDevice>> getAudioOutputDevices() async {
    return await Hardware.instance.enumerateDevices(type: 'audiooutput');
  }

  /// 销毁
  void dispose() {
    _deviceChangeSubscription?.cancel();
    _deviceChangeListeners.clear();
  }
}
