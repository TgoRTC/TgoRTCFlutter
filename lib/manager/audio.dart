import 'package:livekit_client/livekit_client.dart';

class AudioManager {
  AudioManager._internal();
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;

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
}

