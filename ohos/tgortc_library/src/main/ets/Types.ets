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
