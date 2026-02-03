import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { TgoRTCFlutter } from '@anthropic/tgortc';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    // 注册 TgoRTC 桥接插件，否则 ArkTS 侧 joinRoom 会报 bridge 未就绪
    flutterEngine.getPlugins()?.add(TgoRTCFlutter.getInstance())
  }
}
