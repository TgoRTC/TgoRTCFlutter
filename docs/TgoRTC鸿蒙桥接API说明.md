# TgoRTC 鸿蒙桥接 API 说明

本文件详细说明了 `tgortcflutter` SDK 通过 `MethodChannel` (名称: `com.tgortc/bridge`) 暴露给鸿蒙原生的接口。

Flutter 入口必须在加入房间前且仅一次调用 `TgoRTCOhosBridge.register()`。通道使用
`StandardMethodCodec`：ArkTS 接收到的 payload 是 `Map`，应通过 `args.get('key')`
读取字段，而不是通过 `args.key` 或 `JSON.stringify(args)` 读取。

使用本页的 XComponent Surface API 时，集成方必须整体更新
`tgortc-<version>.har`、`flutter_webrtc.har`、`flutter.har` 与完整
`flutter_assets/`。其中 `flutter_webrtc.har` 提供将 WebRTC VideoSink 直接绑定到
ArkTS Surface 的能力；只替换 `tgortc` HAR 不会获得多路原生渲染。

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

当前版本的本地摄像头默认采集参数为 `1280×720 @ 30fps`，VP8 顶层最大码率为
`1.7 Mbps`，simulcast 为 `180p / 360p / 720p`。这是 SDK 内部发布参数，`joinRoom` 暂不提供
单独的分辨率字段。此前的 4K 默认值在部分鸿蒙真机上存在 Camera Session 启动成功但无首帧的问题，
因此已降为兼容性更好的 720p。

鸿蒙 native 采集层会在 VideoOutput 启动后等待首帧；800ms 内仍未收到 NativeImage/WebRTC 帧时，会重建
`CameraInput` 并自动切换到同尺寸 PreviewOutput。首次超时后，同一进程的后续摄像头切换会直接使用
PreviewOutput，避免重复等待超时。该行为不需要调用方重新加入房间或重新绑定 Surface。

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
- HarmonyOS 会直接调用 `flutter_webrtc` 音频路由；`Future` 成功后 SDK 内的扬声器状态才会更新。

### switchCamera
切换前后摄像头。
- **参数**: 无。
- 该调用会等待 LiveKit 完成新摄像头创建、sender track 替换及启动，并保留约 300ms 的稳定窗口。切换期间的重复调用会合并到同一个任务，避免多个 Capture Session 并发启停；不使用可能短暂为空的 HarmonyOS outbound stats 阻塞返回。
- HarmonyOS 插件使用视频 track ID 作为 `RTCRtpSender.id` 为空时的稳定 ID，并在 PeerConnection 生命周期内缓存
  sender 映射。正常切换日志应出现 `getRtpSenderById cache hit: <trackId>`，不应再出现
  `rtpSenderSetTrack(): sender is null`。
- LiveKit 替换底层 `MediaStreamTrack` 后，SDK 会自动将原本地 XComponent Surface 重绑到新 track。
  正常日志应出现 `[VideoSurface] rebind ... oldTrack=... newTrack=...`，然后出现同一 `surfaceId`
  的新 `SinkAttach`和 `[VideoSurface] first frame`。
- 如果集成工程已使用本版本的 `flutter_assets`，但仍出现上述 `sender is null`，说明加载的仍是旧
  `flutter_webrtc.har`；需要替换 HAR、重新执行 Sync/构建并卸载旧应用后重装。

### invite
邀请参与者（更新 SDK 内部参与者列表并触发通知）。
- **参数**:
  - `roomName` (string): 房间名。
  - `uids` (string[]): 邀请的 UID 列表。
- SDK 会先完整更新参与者缓存和 `RoomInfo.uidList`，再异步发送一次去重后的
  `onParticipantsChanged` 完整快照；首次快照即包含本次实际接受的 UID，状态为 `isJoined=false`。
- 已存在 UID、当前登录 UID及同批重复 UID会被忽略；超过 `maxParticipants` 的部分不会进入
  `uidList`、参与者缓存或事件快照。

### attachVideoSurface
将指定成员的摄像头轨道绑定到 **已加载** 的 ArkTS `XComponent` Surface。

```ts
await TgoRTCFlutter.attachVideoSurface({
  uid: 'remote-user-id',
  surfaceId: xComponentController.getXComponentSurfaceId(),
  isLocal: false,
  mirror: false,
  fit: 'cover', // 'cover' | 'contain'
})
```

- `surfaceId` 必须来自 `XComponent.onLoad` 后的
  `XComponentController.getXComponentSurfaceId()`；不可预先伪造或跨页面复用。
- 轨道尚未订阅时调用会成功登记并进入 `waiting_track`；轨道可用、重连或替换后会自动绑定。
- 同一成员最多可同时绑定一个主画面和一个小窗；超出限制返回 `renderer_bind_failed`。
- SDK 仅绑定视频输出，不创建 FlutterPage、ArkTS 网格或其他 UI。

### detachVideoSurface
幂等地释放一个视频格子的 renderer/sink。

```ts
await TgoRTCFlutter.detachVideoSurface({ surfaceId })
```

在成员离开、页面重排、`XComponent.onDestroy`、最小化、挂断前调用。它只移除当前
renderer 的 VideoSink，**不会**停止该成员共享的摄像头或远端视频轨道。

### updateVideoSurface
原子更新已绑定 Surface 的镜像和填充方式，不重建轨道。

```ts
await TgoRTCFlutter.updateVideoSurface({
  surfaceId,
  mirror: true,
  fit: 'contain',
})
```

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
房间参与者列表发生变化。以下场景均会推送完整列表：本地加入、邀请成员、远端加入、远端离开及本地媒体状态变化。
`uidList` 中的受邀成员会先以占位成员出现，只有 `isJoined` 为 `true` 才表示该成员已实际进入 LiveKit 房间。
一次同步操作产生的多个成员变化会合并为一个微任务快照，避免连续发送内容相同的完整列表。
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

### onVideoSurfaceStateChanged
ArkTS Surface 与真实 WebRTC VideoSink 的状态变化。
- **Payload**:
  - `roomName` (string)
  - `surfaceId` (string)
  - `uid` (string)
  - `state` (`rendering` | `waiting_track` | `detached` | `error`)
  - `reason` (string，可选)

`rendering` 在 native renderer 收到首帧后触发。`waiting_track` 表示成员或摄像头轨道
尚未可用，ArkTS 应保留头像占位而不是重试进房；`detached` 表示可安全销毁对应格子。

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

## 6. Flutter Texture 视频层（可选）

当 ArkTS XComponent 外部 Surface 无法满足 `cover/contain` 的原生裁切效果时，可改用
单个 FlutterPage 承载 `TgoFlutterVideoTextureLayer`。ArkTS 通过
`setFlutterVideoLayout({ tiles, animationDurationMs?, animationCurve? })` 下发完整的归一化
视频格子布局，并通过 `clearFlutterVideoLayout()` 清理。旧 XComponent API 保持可用。

该方案依赖 `flutter_webrtc` 内包含 `NativeVideoRenderer.initFlutterTexture` 的 native 修复版；
它把 Flutter `TextureRegistry` Surface 切换到 CPU/RGBA 输出，避免旧 EGL 路径的
`eglMakeCurrent in update failed` 黑屏。仅更新 `tgortc` HAR 或 Dart `flutter_assets` 不会修复
该 native 问题。

完整架构、Flutter 入口、悬浮小窗及动画同步示例见
[`鸿蒙FlutterTexture视频层集成说明.md`](鸿蒙FlutterTexture视频层集成说明.md)。

## 7. 错误代码说明

当调用失败时，会通过 `PlatformException` 返回：
- `unsupported_method`: 调用了不存在的方法。
- `StateError`: SDK 状态异常（如未初始化就调用加入房间）。
- `surface_not_found`: `surfaceId` 为空、未登记或已销毁。
- `participant_not_found`: UID 不在当前房间。
- `renderer_bind_failed`: renderer 创建、轨道绑定、参数校验或配额检查失败。
- `invalid_flutter_video_layout`: Flutter Texture 布局参数非法、tileId 重复或归一化矩形越界。
