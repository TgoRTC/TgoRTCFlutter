# TgoRTC 鸿蒙桥接 API 说明

本文件详细说明了 `tgortcflutter` SDK 通过 `MethodChannel` (名称: `com.tgortc/bridge`) 暴露给鸿蒙原生的接口。

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

### getCurrentRoomInfo
获取当前房间详情。
- **返回值**: `RoomInfo` 对象 Map (详见第 4 节)。

### getAllParticipants
获取所有参与者列表。
- **返回值**: `Participant[]` 数组 (详见第 4 节)。

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
房间参与者列表发生变化（有人加入或离开）。
- **Payload**:
  - `count` (number): 当前总人数。
  - `participants` (Participant[]): 完整的参与者列表。

### onLocalMediaStatusChanged
本地媒体状态发生变化（例如由于系统或其他原因导致的静音）。
- **Payload**:
  - `micEnabled` (boolean)
  - `cameraEnabled` (boolean)

---

## 4. 数据结构定义

### Participant 对象
```json
{
  "uid": "string",
  "isLocal": "boolean",
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
## 5. 错误代码说明

当调用失败时，会通过 `PlatformException` 返回：
- `unsupported_method`: 调用了不存在的方法。
- `StateError`: SDK 状态异常（如未初始化就调用加入房间）。
