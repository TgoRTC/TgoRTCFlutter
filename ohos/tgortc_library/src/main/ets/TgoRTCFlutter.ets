import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos'
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel'
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall'
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger'
import StandardMethodCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMethodCodec'
import { RoomInfo, Participant, ConnectStatus, ConnectStatusInfo, TgoRTCEventListener, JoinRoomParams, InitParams, InviteParams } from './Types'
import hilog from '@ohos.hilog'

// 日志 TAG 和 Domain
const TAG = 'TgoRTCFlutter'
const DOMAIN = 0x0001

/**
 * TgoRTC Flutter SDK 主入口类
 *
 * 提供音视频通话的核心功能，包括：
 * - 初始化 SDK
 * - 房间管理（加入/离开）
 * - 音视频控制（麦克风/摄像头/扬声器）
 * - 事件监听
 *
 * @example
 * ```typescript
 * // 在 EntryAbility 中注册插件
 * flutterEngine.getPlugins()?.add(TgoRTCFlutter.getInstance())
 *
 * // 设置监听
 * TgoRTCFlutter.getInstance().setEventListener({
 *   onConnectStatusChanged: (roomName, status, reason) => {
 *     console.info(`Room ${roomName} status: ${status}`)
 *   }
 * })
 *
 * // 加入房间
 * await TgoRTCFlutter.getInstance().joinRoom({
 *   roomName: 'test-room',
 *   token: 'your-token',
 *   url: 'wss://your-server.com',
 *   loginUID: 'user-123'
 * })
 * ```
 */
export class TgoRTCFlutter implements FlutterPlugin, MethodCallHandler {
  private static instance: TgoRTCFlutter | null = null
  private channel: MethodChannel | null = null
  private binaryMessenger: BinaryMessenger | null = null
  private eventListener: TgoRTCEventListener | null = null
  private isInitialized: boolean = false
  private pendingResults: Map<string, MethodResult> = new Map()
  private callIdCounter: number = 0

  private constructor() {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] Constructor called - creating singleton instance')
  }

  /**
   * 获取单例实例
   */
  static getInstance(): TgoRTCFlutter {
    hilog.debug(DOMAIN, TAG, `[TgoRTCFlutter] getInstance called, current instance: ${TgoRTCFlutter.instance !== null ? 'exists' : 'null'}`)
    if (TgoRTCFlutter.instance === null) {
      TgoRTCFlutter.instance = new TgoRTCFlutter()
      hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] Created new singleton instance')
    }
    return TgoRTCFlutter.instance
  }

  /**
   * 静态方法：加入房间（便捷方法）
   */
  static async joinRoom(roomInfo: RoomInfo): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter.static] joinRoom called: room=${roomInfo.roomName}, url=${roomInfo.url}`)
    return TgoRTCFlutter.getInstance().joinRoom(roomInfo)
  }

  /**
   * 静态方法：离开房间（便捷方法）
   */
  static async leaveRoom(): Promise<void> {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter.static] leaveRoom called')
    return TgoRTCFlutter.getInstance().leaveRoom()
  }

  /**
   * 静态方法：设置麦克风状态（便捷方法）
   */
  static async setMicrophoneEnabled(enabled: boolean): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter.static] setMicrophoneEnabled: ${enabled}`)
    return TgoRTCFlutter.getInstance().setMicrophoneEnabled(enabled)
  }

  /**
   * 静态方法：设置摄像头状态（便捷方法）
   */
  static async setCameraEnabled(enabled: boolean): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter.static] setCameraEnabled: ${enabled}`)
    return TgoRTCFlutter.getInstance().setCameraEnabled(enabled)
  }

  /**
   * 静态方法：设置扬声器状态（便捷方法）
   */
  static async setSpeakerphoneOn(on: boolean): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter.static] setSpeakerphoneOn: ${on}`)
    return TgoRTCFlutter.getInstance().setSpeakerphoneOn(on)
  }

  /**
   * 静态方法：当前是否处于通话生命周期内（包含 connecting/reconnecting）。
   */
  static async isCalling(): Promise<boolean> {
    return TgoRTCFlutter.getInstance().isCalling()
  }

  /** 静态方法：获取当前连接状态。 */
  static async getConnectStatus(): Promise<ConnectStatusInfo> {
    return TgoRTCFlutter.getInstance().getConnectStatus()
  }

  /** 静态方法：获取当前房间信息。 */
  static async getCurrentRoomInfo(): Promise<RoomInfo> {
    return TgoRTCFlutter.getInstance().getCurrentRoomInfo()
  }

  /**
   * FlutterPlugin 接口实现 - 返回唯一类名
   */
  getUniqueClassName(): string {
    return 'TgoRTCFlutter'
  }

  /**
   * FlutterPlugin 接口实现 - 附加到 Flutter 引擎
   */
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] onAttachedToEngine START')
    this.binaryMessenger = binding.getBinaryMessenger()
    hilog.debug(DOMAIN, TAG, `[TgoRTCFlutter] Got binaryMessenger: ${this.binaryMessenger !== null ? 'valid' : 'null'}`)
    
    // Match Dart's default MethodChannel codec explicitly. StandardMethodCodec
    // decodes Dart Map values into ArkTS Map instances, not plain objects.
    this.channel = new MethodChannel(this.binaryMessenger, 'com.tgortc/bridge', StandardMethodCodec.INSTANCE)
    hilog.debug(DOMAIN, TAG, '[TgoRTCFlutter] Created MethodChannel: com.tgortc/bridge')
    
    this.channel.setMethodCallHandler(this)
    hilog.debug(DOMAIN, TAG, '[TgoRTCFlutter] Set MethodCallHandler')
    
    this.isInitialized = true
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] onAttachedToEngine COMPLETE - isInitialized=true')
  }

  /**
   * FlutterPlugin 接口实现 - 从 Flutter 引擎分离
   */
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] onDetachedFromEngine START')
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null)
      this.channel = null
      hilog.debug(DOMAIN, TAG, '[TgoRTCFlutter] Cleared MethodChannel')
    }
    this.binaryMessenger = null
    this.isInitialized = false
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] onDetachedFromEngine COMPLETE - isInitialized=false')
  }

  /**
   * MethodCallHandler 接口实现 - 处理来自 Flutter 的方法调用
   */
  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] onMethodCall: method=${call.method}`)
    this.handleFlutterEvent(call)
    result.success(null)
  }

  /**
   * 设置事件监听器
   */
  setEventListener(listener: TgoRTCEventListener): void {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] setEventListener called')
    this.eventListener = listener
  }

  /**
   * 初始化 SDK（可选配置）
   */
  async init(options?: InitOptions): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] init called with options: ${JSON.stringify(options)}`)
    this.checkInitialized()
    return new Promise<void>((resolve, reject) => {
      const callId = this.generateCallId()
      hilog.debug(DOMAIN, TAG, `[TgoRTCFlutter] init invoking Flutter method with callId: ${callId}`)
      const initParams: InitParams = {
        callId: callId,
        debug: options?.debug ?? true,
        mirror: options?.mirror ?? true
      }
      this.channel?.invokeMethod('init', initParams, {
        success: () => {
          hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] init SUCCESS')
          resolve()
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] init ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] init NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /**
   * 加入房间
   */
  async joinRoom(roomInfo: RoomInfo): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] joinRoom START: room=${roomInfo.roomName}, url=${roomInfo.url}, uid=${roomInfo.loginUID}`)
    hilog.debug(DOMAIN, TAG, `[TgoRTCFlutter] joinRoom full params: ${JSON.stringify(roomInfo)}`)
    this.checkInitialized()
    return new Promise<void>((resolve, reject) => {
      const params: JoinRoomParams = {
        roomName: roomInfo.roomName,
        token: roomInfo.token,
        url: roomInfo.url,
        loginUID: roomInfo.loginUID,
        creatorUID: roomInfo.creatorUID ?? roomInfo.loginUID,
        maxParticipants: roomInfo.maxParticipants ?? 9,
        rtcType: roomInfo.rtcType ?? 1,
        isP2P: roomInfo.isP2P ?? false,
        uidList: roomInfo.uidList ?? [],
        timeout: roomInfo.timeout ?? 30,
        micEnabled: roomInfo.micEnabled ?? true,
        cameraEnabled: roomInfo.cameraEnabled ?? true
      }
      hilog.debug(DOMAIN, TAG, `[TgoRTCFlutter] joinRoom invoking Flutter with: ${JSON.stringify(params)}`)
      this.channel?.invokeMethod('joinRoom', params, {
        success: () => {
          hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] joinRoom SUCCESS')
          resolve()
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] joinRoom ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] joinRoom NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /**
   * 离开房间
   */
  async leaveRoom(): Promise<void> {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] leaveRoom START')
    this.checkInitialized()
    return new Promise<void>((resolve, reject) => {
      this.channel?.invokeMethod('leaveRoom', null, {
        success: () => {
          hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] leaveRoom SUCCESS')
          resolve()
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] leaveRoom ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] leaveRoom NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /**
   * 设置麦克风状态
   */
  async setMicrophoneEnabled(enabled: boolean): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] setMicrophoneEnabled: ${enabled}`)
    this.checkInitialized()
    return new Promise<void>((resolve, reject) => {
      this.channel?.invokeMethod('setMicrophoneEnabled', enabled, {
        success: () => {
          hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] setMicrophoneEnabled SUCCESS')
          resolve()
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] setMicrophoneEnabled ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] setMicrophoneEnabled NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /**
   * 设置摄像头状态
   */
  async setCameraEnabled(enabled: boolean): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] setCameraEnabled: ${enabled}`)
    this.checkInitialized()
    return new Promise<void>((resolve, reject) => {
      this.channel?.invokeMethod('setCameraEnabled', enabled, {
        success: () => {
          hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] setCameraEnabled SUCCESS')
          resolve()
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] setCameraEnabled ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] setCameraEnabled NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /**
   * 设置扬声器状态
   */
  async setSpeakerphoneOn(on: boolean): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] setSpeakerphoneOn: ${on}`)
    this.checkInitialized()
    return new Promise<void>((resolve, reject) => {
      this.channel?.invokeMethod('setSpeakerphoneOn', on, {
        success: () => {
          hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] setSpeakerphoneOn SUCCESS')
          resolve()
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] setSpeakerphoneOn ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] setSpeakerphoneOn NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /**
   * 切换摄像头（前/后）
   */
  async switchCamera(): Promise<void> {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] switchCamera START')
    this.checkInitialized()
    return new Promise<void>((resolve, reject) => {
      this.channel?.invokeMethod('switchCamera', null, {
        success: () => {
          hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] switchCamera SUCCESS')
          resolve()
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] switchCamera ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] switchCamera NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /**
   * 邀请参与者
   */
  async invite(roomName: string, uids: string[]): Promise<void> {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] invite: room=${roomName}, uids=${JSON.stringify(uids)}`)
    this.checkInitialized()
    return new Promise<void>((resolve, reject) => {
      const inviteParams: InviteParams = { roomName: roomName, uids: uids }
      this.channel?.invokeMethod('invite', inviteParams, {
        success: () => {
          hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] invite SUCCESS')
          resolve()
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] invite ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] invite NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /**
   * 获取所有参与者
   */
  async getAllParticipants(): Promise<Participant[]> {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] getAllParticipants START')
    this.checkInitialized()
    return new Promise<Participant[]>((resolve, reject) => {
      this.channel?.invokeMethod('getAllParticipants', null, {
        success: (result: Object) => {
          const participants = result as Participant[]
          hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] getAllParticipants SUCCESS: count=${participants?.length ?? 0}`)
          resolve(participants ?? [])
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] getAllParticipants ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] getAllParticipants NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /** 获取 Dart 房间管理器记录的真实连接状态。 */
  async getConnectStatus(): Promise<ConnectStatusInfo> {
    this.checkInitialized()
    return new Promise<ConnectStatusInfo>((resolve, reject) => {
      this.channel?.invokeMethod('getConnectStatus', null, {
        success: (result: Object) => {
          const value = result as ConnectStatusInfo
          resolve(value)
        },
        error: (code: string, msg: string) => reject(new Error(`${code}: ${msg}`)),
        notImplemented: () => reject(new Error('Method not implemented'))
      })
    })
  }

  /** 获取当前房间信息；离开房间后返回空对象。 */
  async getCurrentRoomInfo(): Promise<RoomInfo> {
    this.checkInitialized()
    return new Promise<RoomInfo>((resolve, reject) => {
      this.channel?.invokeMethod('getCurrentRoomInfo', null, {
        success: (result: Object) => resolve(result as RoomInfo),
        error: (code: string, msg: string) => reject(new Error(`${code}: ${msg}`)),
        notImplemented: () => reject(new Error('Method not implemented'))
      })
    })
  }

  /**
   * 当前是否存在通话房间。
   *
   * 返回 true 表示已开始加入且尚未 leaveRoom；它不表示房间一定已经连接成功。
   * 需要连接成功状态时请监听 onConnectStatusChanged。
   */
  async isCalling(): Promise<boolean> {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] isCalling START')
    this.checkInitialized()
    return new Promise<boolean>((resolve, reject) => {
      this.channel?.invokeMethod('isCalling', null, {
        success: (result: Object) => {
          const isCalling = result as boolean
          hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] isCalling SUCCESS: ${isCalling}`)
          resolve(isCalling ?? false)
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] isCalling ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] isCalling NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  /**
   * 获取扬声器状态
   */
  async isSpeakerOn(): Promise<boolean> {
    hilog.info(DOMAIN, TAG, '[TgoRTCFlutter] isSpeakerOn START')
    this.checkInitialized()
    return new Promise<boolean>((resolve, reject) => {
      this.channel?.invokeMethod('isSpeakerOn', null, {
        success: (result: Object) => {
          const isOn = result as boolean
          hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] isSpeakerOn SUCCESS: ${isOn}`)
          resolve(isOn ?? false)
        },
        error: (code: string, msg: string) => {
          hilog.error(DOMAIN, TAG, `[TgoRTCFlutter] isSpeakerOn ERROR: ${code} - ${msg}`)
          reject(new Error(`${code}: ${msg}`))
        },
        notImplemented: () => {
          hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] isSpeakerOn NOT_IMPLEMENTED')
          reject(new Error('Method not implemented'))
        }
      })
    })
  }

  // 私有方法

  private checkInitialized(): void {
    hilog.debug(DOMAIN, TAG, `[TgoRTCFlutter] checkInitialized: isInitialized=${this.isInitialized}, channel=${this.channel !== null ? 'exists' : 'null'}`)
    if (!this.isInitialized) {
      hilog.error(DOMAIN, TAG, '[TgoRTCFlutter] checkInitialized FAILED - not initialized!')
      throw new Error('TgoRTCFlutter not initialized. Make sure the plugin is registered with FlutterEngine.')
    }
  }

  private generateCallId(): string {
    this.callIdCounter++
    const callId = `call_${this.callIdCounter}_${Date.now()}`
    hilog.debug(DOMAIN, TAG, `[TgoRTCFlutter] Generated callId: ${callId}`)
    return callId
  }

  private handleFlutterEvent(call: MethodCall): void {
    hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] handleFlutterEvent: method=${call.method}`)
    const listener = this.eventListener
    if (listener === null) {
      hilog.warn(DOMAIN, TAG, '[TgoRTCFlutter] handleFlutterEvent: No listener set, ignoring event')
      return
    }

    // The StandardMethodCodec represents a Dart Map as ArkTS Map. Casting it
    // to an interface and reading `.roomName` produced undefined fields (and
    // JSON.stringify(Map) misleadingly logs `{}`). Read all fields via get().
    if (!(call.args instanceof Map)) {
      hilog.warn(DOMAIN, TAG, `[TgoRTCFlutter] Event ${call.method} has non-Map arguments`)
      return
    }
    const args = call.args as Map<string, Object>
    switch (call.method) {
      case 'onConnectStatusChanged':
        if (listener.onConnectStatusChanged !== undefined) {
          const roomName = args.get('roomName') as string
          const status = args.get('status') as number
          const reason = args.get('reason') as string
          hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] Event: onConnectStatusChanged - room=${roomName}, status=${status}, reason=${reason}`)
          listener.onConnectStatusChanged(
            roomName,
            status as ConnectStatus,
            reason
          )
        }
        break

      case 'onParticipantsChanged':
        if (listener.onParticipantsChanged !== undefined) {
          const count = args.get('count') as number
          const participants = args.get('participants') as Participant[]
          hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] Event: onParticipantsChanged - count=${count}`)
          listener.onParticipantsChanged(
            count,
            participants
          )
        }
        break

      case 'onLocalMediaStatusChanged':
        if (listener.onLocalMediaStatusChanged !== undefined) {
          const micEnabled = args.get('micEnabled') as boolean
          const cameraEnabled = args.get('cameraEnabled') as boolean
          hilog.info(DOMAIN, TAG, `[TgoRTCFlutter] Event: onLocalMediaStatusChanged - mic=${micEnabled}, camera=${cameraEnabled}`)
          listener.onLocalMediaStatusChanged(
            micEnabled,
            cameraEnabled
          )
        }
        break

      case 'onRemoteParticipantLeft':
        if (listener.onRemoteParticipantLeft !== undefined) {
          listener.onRemoteParticipantLeft(
            args.get('roomName') as string,
            args.get('uid') as string,
            args.get('reason') as string
          )
        }
        break

      case 'onRoomDisconnected':
        if (listener.onRoomDisconnected !== undefined) {
          listener.onRoomDisconnected(
            args.get('roomName') as string,
            args.get('reason') as string
          )
        }
        break

      case 'onAudioOutputDeviceChanged':
        if (listener.onAudioOutputDeviceChanged !== undefined) {
          listener.onAudioOutputDeviceChanged(
            args.get('speakerphoneOn') as boolean,
            args.get('deviceName') as string
          )
        }
        break

      case 'onParticipantSpeaking':
        if (listener.onParticipantSpeaking !== undefined) {
          listener.onParticipantSpeaking(
            args.get('roomName') as string,
            args.get('uid') as string,
            args.get('isLocal') as boolean,
            args.get('isSpeaking') as boolean,
            args.get('audioLevel') as number
          )
        }
        break

      case 'onVideoTrackChanged':
        if (listener.onVideoTrackChanged !== undefined) {
          listener.onVideoTrackChanged(
            args.get('roomName') as string,
            args.get('uid') as string,
            args.get('isLocal') as boolean,
            args.get('available') as boolean,
            args.get('muted') as boolean
          )
        }
        break

      default:
        hilog.warn(DOMAIN, TAG, `[TgoRTCFlutter] Unknown event: ${call.method}`)
        break
    }
  }
}

/**
 * 初始化选项
 */
export interface InitOptions {
  debug?: boolean
  mirror?: boolean
}
