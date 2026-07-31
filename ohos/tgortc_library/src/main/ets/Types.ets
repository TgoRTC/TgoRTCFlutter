/**
 * TgoRTC 类型定义
 */

/**
 * 房间信息
 */
export interface RoomInfo {
  roomName: string
  token: string
  url: string
  loginUID: string
  creatorUID?: string
  maxParticipants?: number
  rtcType?: number // 1: video, 0: audio
  isP2P?: boolean
  uidList?: string[]
  timeout?: number
  micEnabled?: boolean
  cameraEnabled?: boolean
}

/**
 * 参与者信息
 */
export interface Participant {
  uid: string
  isLocal: boolean
  /** True only after this uid has joined the LiveKit room. */
  isJoined: boolean
  micEnabled: boolean
  cameraEnabled: boolean
}

/**
 * 连接状态
 */
export enum ConnectStatus {
  CONNECTING = 0,
  CONNECTED = 1,
  DISCONNECTED = 2
}

/** 当前连接状态查询结果。 */
export interface ConnectStatusInfo {
  roomName: string
  status: ConnectStatus
  reason: string
}

/** XComponent 视频填充方式。 */
export type VideoFit = 'cover' | 'contain'

/** 将指定成员摄像头轨道绑定到已加载的 ArkTS XComponent Surface。 */
export interface AttachVideoSurfaceParams {
  uid: string
  surfaceId: string
  isLocal: boolean
  mirror?: boolean
  fit?: VideoFit
}

/** 解绑一个 ArkTS XComponent Surface。 */
export interface DetachVideoSurfaceParams {
  surfaceId: string
}

/** 原子更新已绑定 Surface 的展示参数。 */
export interface UpdateVideoSurfaceParams {
  surfaceId: string
  mirror?: boolean
  fit?: VideoFit
}

/**
 * One video Texture rectangle inside the single FlutterPage used by the
 * ArkTS-controlled renderer. All geometry is normalised to that page's
 * viewport, so ArkTS does not need to convert vp/px to Flutter logical pixels.
 */
export interface FlutterVideoTile {
  tileId: string
  uid: string
  isLocal: boolean
  left: number
  top: number
  width: number
  height: number
  zIndex?: number
  visible?: boolean
  mirror?: boolean
  fit?: VideoFit
}

/** Updates the complete Flutter Texture video layout atomically. */
export interface SetFlutterVideoLayoutParams {
  tiles: FlutterVideoTile[]
  /** Optional Flutter-side animation duration, 0..5000 ms. */
  animationDurationMs?: number
  /** Must match ArkTS overlay animation: linear/easeIn/easeOut/easeInOut. */
  animationCurve?: 'linear' | 'easeIn' | 'easeOut' | 'easeInOut'
}

/** ArkTS Surface 与 WebRTC VideoSink 的真实状态。 */
export type VideoSurfaceState = 'rendering' | 'waiting_track' | 'detached' | 'error'

/**
 * 事件监听器接口
 */
export interface TgoRTCEventListener {
  /**
   * 连接状态变化
   */
  onConnectStatusChanged?: (roomName: string, status: ConnectStatus, reason: string) => void

  /**
   * 参与者列表变化
   */
  onParticipantsChanged?: (count: number, participants: Participant[]) => void

  /**
   * 本地媒体状态变化
   */
  onLocalMediaStatusChanged?: (micEnabled: boolean, cameraEnabled: boolean) => void

  /** 远端成员离开（P2P 页面可据此自动挂断）。 */
  onRemoteParticipantLeft?: (roomName: string, uid: string, reason: string) => void

  /** 房间最终断开。 */
  onRoomDisconnected?: (roomName: string, reason: string) => void

  /** 实际音频输出路由发生变化。 */
  onAudioOutputDeviceChanged?: (speakerphoneOn: boolean, deviceName: string) => void

  /** 成员说话状态或音量变化。 */
  onParticipantSpeaking?: (roomName: string, uid: string, isLocal: boolean, isSpeaking: boolean, audioLevel: number) => void

  /** 摄像头轨道可用性或静音状态变化。 */
  onVideoTrackChanged?: (roomName: string, uid: string, isLocal: boolean, available: boolean, muted: boolean) => void

  /** ArkTS XComponent Surface 的绑定、首帧和释放状态。 */
  onVideoSurfaceStateChanged?: (roomName: string, surfaceId: string, uid: string, state: VideoSurfaceState, reason?: string) => void
}

/**
 * 连接状态变化事件参数
 */
export interface ConnectStatusArgs {
  roomName: string
  status: number
  reason: string
}

/**
 * 参与者变化事件参数
 */
export interface ParticipantsChangedArgs {
  count: number
  participants: Participant[]
}

/**
 * 媒体状态变化事件参数
 */
export interface MediaStatusArgs {
  micEnabled: boolean
  cameraEnabled: boolean
}

/** 远端参与者离开事件参数。 */
export interface RemoteParticipantLeftArgs {
  roomName: string
  uid: string
  reason: string
}

/** 音频输出路由变化事件参数。 */
export interface AudioOutputDeviceChangedArgs {
  speakerphoneOn: boolean
  deviceName: string
}

/** 成员说话事件参数。 */
export interface ParticipantSpeakingArgs {
  roomName: string
  uid: string
  isLocal: boolean
  isSpeaking: boolean
  audioLevel: number
}

/** 视频轨道状态事件参数。 */
export interface VideoTrackChangedArgs {
  roomName: string
  uid: string
  isLocal: boolean
  available: boolean
  muted: boolean
}

/** XComponent 视频 Surface 状态事件参数。 */
export interface VideoSurfaceStateChangedArgs {
  roomName: string
  surfaceId: string
  uid: string
  state: VideoSurfaceState
  reason?: string
}

/**
 * 加入房间参数（用于 MethodChannel 调用）
 */
export interface JoinRoomParams {
  roomName: string
  token: string
  url: string
  loginUID: string
  creatorUID: string
  maxParticipants: number
  rtcType: number
  isP2P: boolean
  uidList: string[]
  timeout: number
  micEnabled: boolean
  cameraEnabled: boolean
}

/**
 * 初始化参数（用于 MethodChannel 调用）
 */
export interface InitParams {
  callId: string
  debug: boolean
  mirror: boolean
}

/**
 * 邀请参数（用于 MethodChannel 调用）
 */
export interface InviteParams {
  roomName: string
  uids: string[]
}
