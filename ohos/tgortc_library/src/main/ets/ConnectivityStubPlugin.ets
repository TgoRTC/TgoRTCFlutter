import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos'
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel'
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall'
import hilog from '@ohos.hilog'

// 日志 TAG 和 Domain
const TAG = 'ConnectivityStubPlugin'
const DOMAIN = 0x0001

/**
 * Connectivity Stub Plugin for HarmonyOS NEXT
 * 
 * 这个插件为 connectivity_plus 提供一个 stub 实现，
 * 因为 livekit_client 依赖 connectivity_plus 来检查网络状态，
 * 但 connectivity_plus 没有官方的鸿蒙实现。
 * 
 * 这个 stub 会：
 * - 对 'check' 方法返回 'wifi'，表示网络可用
 * - 对 'getAll' 方法返回 ['wifi']，表示 WiFi 连接可用
 */
export class ConnectivityStubPlugin implements FlutterPlugin, MethodCallHandler {
  private static instance: ConnectivityStubPlugin | null = null
  private channel: MethodChannel | null = null

  private constructor() {
    hilog.info(DOMAIN, TAG, '[ConnectivityStubPlugin] Constructor called')
  }

  /**
   * 获取单例实例
   */
  static getInstance(): ConnectivityStubPlugin {
    if (ConnectivityStubPlugin.instance === null) {
      ConnectivityStubPlugin.instance = new ConnectivityStubPlugin()
      hilog.info(DOMAIN, TAG, '[ConnectivityStubPlugin] Created new singleton instance')
    }
    return ConnectivityStubPlugin.instance
  }

  /**
   * FlutterPlugin 接口实现 - 返回唯一类名
   */
  getUniqueClassName(): string {
    return 'ConnectivityStubPlugin'
  }

  /**
   * FlutterPlugin 接口实现 - 附加到 Flutter 引擎
   */
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    hilog.info(DOMAIN, TAG, '[ConnectivityStubPlugin] onAttachedToEngine START')
    
    // 注册 connectivity_plus 的 MethodChannel
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      'dev.fluttercommunity.plus/connectivity'
    )
    hilog.debug(DOMAIN, TAG, '[ConnectivityStubPlugin] Created MethodChannel: dev.fluttercommunity.plus/connectivity')
    
    this.channel.setMethodCallHandler(this)
    hilog.debug(DOMAIN, TAG, '[ConnectivityStubPlugin] Set MethodCallHandler')
    
    hilog.info(DOMAIN, TAG, '[ConnectivityStubPlugin] onAttachedToEngine COMPLETE')
  }

  /**
   * FlutterPlugin 接口实现 - 从 Flutter 引擎分离
   */
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    hilog.info(DOMAIN, TAG, '[ConnectivityStubPlugin] onDetachedFromEngine START')
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null)
      this.channel = null
      hilog.debug(DOMAIN, TAG, '[ConnectivityStubPlugin] Cleared MethodChannel')
    }
    hilog.info(DOMAIN, TAG, '[ConnectivityStubPlugin] onDetachedFromEngine COMPLETE')
  }

  /**
   * MethodCallHandler 接口实现 - 处理来自 Flutter 的方法调用
   */
  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.info(DOMAIN, TAG, `[ConnectivityStubPlugin] onMethodCall: method=${call.method}`)
    
    switch (call.method) {
      case 'check':
        // 返回 'wifi' 表示网络可用
        // 可能的值: wifi, mobile, ethernet, vpn, bluetooth, other, none
        hilog.info(DOMAIN, TAG, '[ConnectivityStubPlugin] check -> returning "wifi"')
        result.success('wifi')
        break
        
      case 'getAll':
        // 返回连接类型列表
        hilog.info(DOMAIN, TAG, '[ConnectivityStubPlugin] getAll -> returning ["wifi"]')
        result.success(['wifi'])
        break
        
      default:
        hilog.warn(DOMAIN, TAG, `[ConnectivityStubPlugin] Unknown method: ${call.method}`)
        result.notImplemented()
        break
    }
  }
}
