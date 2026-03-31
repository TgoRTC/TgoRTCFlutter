import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

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

  String? get currentAudioInputDeviceId =>
      Hardware.instance.selectedAudioInput?.deviceId;

  String? get currentAudioOutputDeviceId =>
      Hardware.instance.selectedAudioOutput?.deviceId;

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
  /// - [forceSpeakerOutput]: 预留参数。当前依赖版本的 livekit_client
  ///   不支持该能力，因此这里会忽略这个参数。
  Future<void> setSpeakerphoneOn(bool on,
      {bool forceSpeakerOutput = false}) async {
    await Hardware.instance.setSpeakerphoneOn(on);
    _isSpeakerOn = on;
  }

  /// 切换扬声器状态
  Future<void> toggleSpeakerphone() async {
    await setSpeakerphoneOn(!_isSpeakerOn);
  }

  /// 是否可以切换扬声器
  bool get canSwitchSpeakerphone => Hardware.instance.canSwitchSpeakerphone;

  /// 当前是否使用扬声器
  bool? get speakerOn => Hardware.instance.speakerOn;

  /// 获取音频输入设备列表（麦克风）
  Future<List<MediaDevice>> getAudioInputDevices() async {
    return await Hardware.instance.enumerateDevices(type: 'audioinput');
  }

  /// 获取音频输出设备列表（扬声器/耳机）
  Future<List<MediaDevice>> getAudioOutputDevices() async {
    return await Hardware.instance.enumerateDevices(type: 'audiooutput');
  }

  /// 获取指定类型的设备列表
  Future<List<MediaDevice>> getDevices(String kind) async {
    return await Hardware.instance.enumerateDevices(type: kind);
  }

  /// 切换音频输入设备（麦克风）
  Future<bool> switchAudioInputDevice(String deviceId,
      {bool setAsDefault = true}) async {
    try {
      final devices = await getAudioInputDevices();
      final device = devices
          .where((item) => item.deviceId == deviceId)
          .cast<MediaDevice?>()
          .firstWhere((item) => item != null, orElse: () => null);
      if (device == null) {
        return false;
      }
      await Hardware.instance.selectAudioInput(device);
      if (!setAsDefault) {
        Hardware.instance.selectedAudioInput = null;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 切换音频输出设备（扬声器/耳机）
  Future<bool> switchAudioOutputDevice(String deviceId,
      {bool setAsDefault = true}) async {
    try {
      final devices = await getAudioOutputDevices();
      final device = devices
          .where((item) => item.deviceId == deviceId)
          .cast<MediaDevice?>()
          .firstWhere((item) => item != null, orElse: () => null);
      if (device == null) {
        return false;
      }
      await Hardware.instance.selectAudioOutput(device);
      if (!setAsDefault) {
        Hardware.instance.selectedAudioOutput = null;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 销毁
  void dispose() {
    _deviceChangeSubscription?.cancel();
    _deviceChangeListeners.clear();
  }
}
