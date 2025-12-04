import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

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
    await Hardware.instance
        .setSpeakerphoneOn(on, forceSpeakerOutput: forceSpeakerOutput);
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

  /// 销毁
  void dispose() {
    _deviceChangeSubscription?.cancel();
    _deviceChangeListeners.clear();
  }
}
