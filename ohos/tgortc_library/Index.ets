/**
 * TgoRTC Flutter SDK for HarmonyOS NEXT
 * 
 * 音视频通话 SDK - 提供房间管理、参与者管理、音视频控制等功能
 * 
 * 注意：视频显示请直接使用 @ohos/flutter_ohos 提供的 FlutterPage 组件
 * import { FlutterPage } from '@ohos/flutter_ohos'
 */

// 主入口类
export { TgoRTCFlutter, InitOptions } from './src/main/ets/TgoRTCFlutter'

// Connectivity Stub Plugin - 为 livekit_client 提供 connectivity_plus 的 stub 实现
export { ConnectivityStubPlugin } from './src/main/ets/ConnectivityStubPlugin'

// 类型定义
export { RoomInfo, Participant, ConnectStatus, ConnectStatusInfo, VideoFit, AttachVideoSurfaceParams, DetachVideoSurfaceParams, UpdateVideoSurfaceParams, FlutterVideoTile, SetFlutterVideoLayoutParams, VideoSurfaceState, TgoRTCEventListener, JoinRoomParams, InitParams, InviteParams, RemoteParticipantLeftArgs, AudioOutputDeviceChangedArgs, ParticipantSpeakingArgs, VideoTrackChangedArgs, VideoSurfaceStateChangedArgs } from './src/main/ets/Types'
