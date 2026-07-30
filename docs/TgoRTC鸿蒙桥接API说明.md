# TgoRTC 鸿蒙桥接 API 说明

本文件详细说明了 `tgortcflutter` SDK 通过 `MethodChannel` (名称: `com.tgortc/bridge`) 暴露给鸿蒙原生的接口。

Flutter 入口必须在加入房间前且仅一次调用 `TgoRTCOhosBridge.register()`。通道使用
`StandardMethodCodec`：ArkTS 接收到的 payload 是 `Map`，应通过 `args.get('key')`
读取字段，而不是通过 `args.key` 或 `JSON.stringify(args)` 读取。

---

## 1. 指令型 API (ArkTS -> Flutter)

这些方法用于控制通话行为。

### init
初始化 SDK。
- **参数**:
  - `debug` (boolean): 是否开启调试模式，默认 `true`。
  - `mirror` (boolean): 是否开启镜像，默认 `true`。

### joinRoom
加入房间。
- **参数**:
  - `roomName` (string): 房间名称。
  - `token` (string): LiveKit 令牌。
  - `url` (string): 服务器地址 (wss://...)。
  - `loginUID` (string): 当前登录用户的 UID。
  - `micEnabled` (boolean, 可选): 初始是否开启麦克风，默认 `true`。
  - `cameraEnabled` (boolean, 可选): 初始是否开启摄像头，默认 `true`。
  - `maxParticipants` (number, 可选): 最大人数限制，默认 `9`。

### leaveRoom
离开当前房间。
- **参数**: 无。

### setMicrophoneEnabled
控制本地麦克风。
- **参数**: `enabled` (boolean)。

### setCameraEnabled
控制本地摄像头。
- **参数**: `enabled` (boolean)。

### setSpeakerphoneOn
控制扬声器开关。
- **参数**: `on` (boolean)。

### switchCamera
切换前后摄像头。
- **参数**: 无。

### invite
邀请参与者（更新 SDK 内部参与者列表并触发通知）。
- **参数**:
  - `roomName` (string): 房间名。
  - `uids` (string[]): 邀请的 UID 列表。

---

## 2. 查询型 API (ArkTS -> Flutter)

这些方法用于获取当前状态。

### getConnectStatus
获取当前连接状态。
- **返回值**:
  - `roomName` (string)
  - `status` (number): 0: Connecting, 1: Connected, 2: Disconnected.
  - `reason` (string)

返回值来自 Flutter 房间管理器的实际状态，不会把“正在连接”伪报为 `Connected`。断线后仍保留最近一次房间名和断开原因，直到下一次加入房间覆盖它。

### getCurrentRoomInfo
获取当前房间详情。
- **返回值**: `RoomInfo` 对象 Map (详见第 4 节)。

### getAllParticipants
获取所有参与者列表。
- **返回值**: `Participant[]` 数组 (详见第 4 节)。

### isCalling
当前是否处于通话生命周期内。
- **返回值**: `boolean`。
- **语义**: 从开始 `joinRoom` 到 `leaveRoom` 清理房间前均为 `true`，包括 Connecting 和 Reconnecting；它不等同于已连接。需要判断已连接状态时请使用 `onConnectStatusChanged`。

---

## 3. 事件通知 (Flutter -> ArkTS)

这些事件由 Flutter 侧主动推送，原生插件需通过 `setMethodCallHandler` 接收。

### onConnectStatusChanged
连接状态发生变化。
- **Payload**:
  - `roomName` (string)
  - `status` (number): 0: Connecting, 1: Connected, 2: Disconnected.
  - `reason` (string)

### onParticipantsChanged
房间参与者列表发生变化。以下场景均会推送完整列表：本地加入、远端加入、远端离开及本地媒体状态变化。
`uidList` 中的受邀成员会先以占位成员出现，只有 `isJoined` 为 `true` 才表示该成员已实际进入 LiveKit 房间。
- **Payload**:
  - `count` (number): 当前总人数。
  - `participants` (Participant[]): 完整的参与者列表。

### onLocalMediaStatusChanged
本地媒体状态发生变化（例如由于系统或其他原因导致的静音）。
- **Payload**:
  - `micEnabled` (boolean)
  - `cameraEnabled` (boolean)

### onRemoteParticipantLeft
远端成员离开。P2P 页面可据此自动挂断。
- **Payload**:
  - `roomName` (string)
  - `uid` (string)
  - `reason` (string)

### onRoomDisconnected
房间最终断开。
- **Payload**:
  - `roomName` (string)
  - `reason` (string)

### onAudioOutputDeviceChanged
音频输出路由变化（包括调用 `setSpeakerphoneOn` 成功后）。
- **Payload**:
  - `speakerphoneOn` (boolean)
  - `deviceName` (string): `Speakerphone` 或 `Earpiece`。

### onParticipantSpeaking
成员说话状态或音量变化。
- **Payload**:
  - `roomName` (string)
  - `uid` (string)
  - `isLocal` (boolean)
  - `isSpeaking` (boolean)
  - `audioLevel` (number): LiveKit 上报的 `0..1` 音量。

### onVideoTrackChanged
摄像头视频轨道的可用性或静音状态变化。
- **Payload**:
  - `roomName` (string)
  - `uid` (string)
  - `isLocal` (boolean)
  - `available` (boolean): 是否存在可渲染的摄像头轨道。
  - `muted` (boolean): 轨道是否被静音。

重连完成会再次触发 `onConnectStatusChanged(Connected, "reconnected")`，并发送完整的 `onParticipantsChanged` 快照；`onRoomDisconnected.reason` 则透传 LiveKit 的断开原因（例如 `clientInitiated`、`participantRemoved`、`reconnectAttemptsExceeded`）。

---

## 4. 数据结构定义

### Participant 对象
```json
{
  "uid": "string",
  "isLocal": "boolean",
  "isJoined": "boolean",
  "micEnabled": "boolean",
  "cameraEnabled": "boolean"
}
```

### RoomInfo 对象
```json
{
  "roomName": "string",
  "token": "string",
  "url": "string",
  "loginUID": "string",
  "creatorUID": "string",
  "maxParticipants": "number",
  "rtcType": "number",
  "isP2P": "boolean",
  "uidList": "string[]",
  "timeout": "number"
}
```
---

### 单聊状态判断

单聊页面不得仅凭存在非本地 `uid` 就进入通话计时。应仅在成员满足
`uid === remoteUid && !isLocal && isJoined` 时调用“对方已接通”逻辑；
`isJoined: false` 表示邀请/预设占位成员，仍应展示等待对方加入。

远端实际进入房间时会触发一次 `onParticipantsChanged`；之后该成员离开会同时触发
`onRemoteParticipantLeft` 和更新后的 `onParticipantsChanged`。P2P 页面可在前者调用
`endByRemote()`。

## 5. 错误代码说明

当调用失败时，会通过 `PlatformException` 返回：
- `unsupported_method`: 调用了不存在的方法。
- `StateError`: SDK 状态异常（如未初始化就调用加入房间）。
