import 'package:flutter/widgets.dart';
import 'package:tgortcflutter/bridge/tgortc_ohos_bridge.dart';
import 'package:tgortcflutter/pages/arkts_video_texture_layer.dart';

/// Alternative HarmonyOS entrypoint for ArkTS-hosted Flutter Texture video.
///
/// Build it with:
/// `flutter build hap --debug -t lib/main_texture.dart`
///
/// The existing `lib/main.dart` is intentionally left unchanged for legacy
/// XComponent Surface integrations.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  TgoRTCOhosBridge.register();
  runApp(const TgoFlutterVideoTextureApp());
}
