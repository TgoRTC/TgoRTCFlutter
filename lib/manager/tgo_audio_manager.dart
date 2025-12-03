import 'package:livekit_client/livekit_client.dart';

class TgoAudioManager {
  TgoAudioManager._internal();
  static final TgoAudioManager _instance = TgoAudioManager._internal();
  static TgoAudioManager get instance => _instance;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  /// 切换扬声器/听筒
  Future<void> setSpeakerphoneOn(bool on) async {
    await Hardware.instance.setSpeakerphoneOn(on);
    _isSpeakerOn = on;
  }

  /// 切换扬声器状态
  Future<void> toggleSpeakerphone() async {
    await setSpeakerphoneOn(!_isSpeakerOn);
  }

  /// 获取音频输入设备列表（麦克风）
  Future<List<MediaDevice>> getAudioInputDevices() async {
    return await Hardware.instance.enumerateDevices(type: 'audioinput');
  }

  /// 获取音频输出设备列表（扬声器/耳机）
  Future<List<MediaDevice>> getAudioOutputDevices() async {
    return await Hardware.instance.enumerateDevices(type: 'audiooutput');
  }

  /// 选择音频输入设备
  Future<void> selectAudioInput(MediaDevice device) async {
    await Hardware.instance.selectAudioInput(device);
  }

  /// 选择音频输出设备
  Future<void> selectAudioOutput(MediaDevice device) async {
    await Hardware.instance.selectAudioOutput(device);
  }
}
