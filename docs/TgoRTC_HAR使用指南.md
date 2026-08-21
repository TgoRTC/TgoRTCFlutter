# TgoRTC HAR 使用指南

本文档介绍如何在鸿蒙 NEXT 原生项目中集成和使用 TgoRTC `1.0.2` 预编译产物。
当前 XComponent 视频路线不能只交付一个 HAR，必须使用同次构建的一整套运行文件。

## 前置条件

- DevEco Studio 5.0+
- HarmonyOS NEXT SDK
- 已有的鸿蒙 NEXT 项目

## 一、导入步骤

### 1. 复制完整 SDK 文件

将 `dist/` 中的主入口产物复制到项目中：

```
YourProject/
├── entry/
│   └── src/main/resources/rawfile/
│       └── flutter_assets/        ← 完整复制目录内容，不要再嵌套一层
├── har/                           ← 创建这个目录
│   ├── tgortc-1.0.2.har           ← TgoRTC ArkTS 桥接
│   ├── flutter_webrtc.har         ← XComponent、摄像头和 WebRTC native 能力
│   └── flutter.har                ← 鸿蒙 Flutter 运行时
├── oh-package.json5
└── build-profile.json5
```

这四部分必须来自同一发布批次。只替换 `tgortc-1.0.2.har` 不会更新 Dart 业务逻辑；
只替换 `flutter_assets/kernel_blob.bin` 也不会更新 `flutter_webrtc.har` 中的 ArkTS/native 视频能力。

### 2. 配置 oh-package.json5

在项目根目录的 `oh-package.json5` 中添加依赖：

```json5
{
  "name": "your_project",
  "version": "1.0.0",
  "dependencies": {
    "@anthropic/tgortc": "file:./har/tgortc-1.0.2.har",
    "@ohos/flutter_ohos": "file:./har/flutter.har",
    "flutter_webrtc": "file:./har/flutter_webrtc.har"
  }
}
```

> **注意**：不要从其他 Flutter SDK 或旧安装包单独抽取 `flutter.har`、`flutter_webrtc.har`
> 或快照文件进行混用。Debug/Release 产物也不能交叉组合。

### 3. 配置 build-profile.json5

确保模块配置正确：

```json5
{
  "app": {
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "compatibleSdkVersion": "5.0.0(12)",
        "runtimeOS": "HarmonyOS"
      }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        {
          "name": "default",
          "applyToProducts": ["default"]
        }
      ]
    }
  ]
}
```

### 4. 同步项目

在 DevEco Studio 中：**File → Sync and Refresh Project**

或命令行：
```bash
ohpm install --all
```

---

## 二、代码集成

### 1. 修改 EntryAbility.ets

注册 TgoRTC 插件：

```typescript
// entry/src/main/ets/entryability/EntryAbility.ets

import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos'
import { TgoRTCFlutter } from '@anthropic/tgortc'

export default class EntryAbility extends FlutterAbility {
  
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    // 注册 TgoRTC 插件
    flutterEngine.getPlugins()?.add(TgoRTCFlutter.getInstance())
  }
}
```

### 2. 创建通话页面

```typescript
// entry/src/main/ets/pages/CallPage.ets

import { TgoRTCFlutter, RoomInfo, ConnectStatus } from '@anthropic/tgortc'
import { FlutterPage } from '@ohos/flutter_ohos'

let storage = LocalStorage.getShared()

@Entry(storage)
@Component
struct CallPage {
  // 从 LocalStorage 获取 Flutter 视图 ID
  @LocalStorageLink('viewId') viewId: string = ''
  
  // 通话状态
  @State isConnected: boolean = false
  @State isMicOn: boolean = true
  @State isCameraOn: boolean = true
  @State isSpeakerOn: boolean = true
  @State participants: number = 0

  aboutToAppear() {
    // 设置事件监听
    TgoRTCFlutter.getInstance().setEventListener({
      onConnectStatusChanged: (roomName: string, status: ConnectStatus, reason: string) => {
        console.info(`[TgoRTC] Room: ${roomName}, Status: ${status}, Reason: ${reason}`)
        this.isConnected = (status === ConnectStatus.CONNECTED)
      },
      onParticipantsChanged: (count: number, participants) => {
        console.info(`[TgoRTC] Participants count: ${count}`)
        this.participants = count
        // 仅真实入房的远端成员可以结束“等待对方加入”并开始计时。
        const remote = participants.find((item) => !item.isLocal && item.isJoined)
        if (remote !== undefined) {
          // markRemoteJoined(remote.uid)
        }
      },
      onLocalMediaStatusChanged: (micEnabled: boolean, cameraEnabled: boolean) => {
        this.isMicOn = micEnabled
        this.isCameraOn = cameraEnabled
      }
    })
  }

  build() {
    Column() {
      // 视频显示区域
      Stack() {
        if (this.viewId !== '') {
          FlutterPage({ viewId: this.viewId })
        } else {
          Text('加载中...')
            .fontSize(16)
            .fontColor('#FFFFFF')
        }
        
        // 参与者数量
        Text(`参与者: ${this.participants}`)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#80000000')
          .padding(8)
          .borderRadius(4)
          .position({ x: 16, y: 16 })
      }
      .width('100%')
      .height('60%')
      .backgroundColor('#1A1A1A')

      // 控制按钮区域
      Row() {
        // 麦克风
        Button(this.isMicOn ? '静音' : '开麦')
          .onClick(() => this.toggleMic())
          .backgroundColor(this.isMicOn ? '#4CAF50' : '#F44336')
          .width(80)
          .height(44)

        // 摄像头
        Button(this.isCameraOn ? '关摄像头' : '开摄像头')
          .onClick(() => this.toggleCamera())
          .backgroundColor(this.isCameraOn ? '#4CAF50' : '#F44336')
          .width(100)
          .height(44)

        // 切换摄像头
        Button('切换')
          .onClick(() => this.switchCamera())
          .width(70)
          .height(44)

        // 扬声器
        Button(this.isSpeakerOn ? '听筒' : '扬声器')
          .onClick(() => this.toggleSpeaker())
          .width(80)
          .height(44)
      }
      .justifyContent(FlexAlign.SpaceEvenly)
      .width('100%')
      .padding(16)

      // 加入/离开按钮
      Row() {
        Button(this.isConnected ? '离开房间' : '加入房间')
          .onClick(() => this.isConnected ? this.leaveRoom() : this.joinRoom())
          .backgroundColor(this.isConnected ? '#F44336' : '#2196F3')
          .width(200)
          .height(50)
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }

  // 加入房间
  async joinRoom() {
    try {
      const roomInfo: RoomInfo = {
        roomName: 'test-room-001',
        token: 'your-auth-token',           // 替换为真实 token
        url: 'wss://your-rtc-server.com',   // 替换为真实服务器地址
        loginUID: 'user-12345',
        micEnabled: true,
        cameraEnabled: true
      }
      
      await TgoRTCFlutter.getInstance().joinRoom(roomInfo)
      console.info('[TgoRTC] Join room success')
    } catch (e) {
      console.error('[TgoRTC] Join room failed:', e)
    }
  }

  // 离开房间
  async leaveRoom() {
    try {
      await TgoRTCFlutter.getInstance().leaveRoom()
      console.info('[TgoRTC] Leave room success')
    } catch (e) {
      console.error('[TgoRTC] Leave room failed:', e)
    }
  }

  // 切换麦克风
  async toggleMic() {
    try {
      await TgoRTCFlutter.getInstance().setMicrophoneEnabled(!this.isMicOn)
      this.isMicOn = !this.isMicOn
    } catch (e) {
      console.error('[TgoRTC] Toggle mic failed:', e)
    }
  }

  // 切换摄像头
  async toggleCamera() {
    try {
      await TgoRTCFlutter.getInstance().setCameraEnabled(!this.isCameraOn)
      this.isCameraOn = !this.isCameraOn
    } catch (e) {
      console.error('[TgoRTC] Toggle camera failed:', e)
    }
  }

  // 切换前后摄像头
  async switchCamera() {
    try {
      await TgoRTCFlutter.getInstance().switchCamera()
    } catch (e) {
      console.error('[TgoRTC] Switch camera failed:', e)
    }
  }

  // 切换扬声器
  async toggleSpeaker() {
    try {
      await TgoRTCFlutter.getInstance().setSpeakerphoneOn(!this.isSpeakerOn)
      this.isSpeakerOn = !this.isSpeakerOn
    } catch (e) {
      console.error('[TgoRTC] Toggle speaker failed:', e)
    }
  }
}
```

`switchCamera()` 会等待 LiveKit 完成新摄像头创建、sender track 替换及启动，并额外保留约
300ms 的首帧稳定窗口；切换期间的重复点击会由 SDK 合并到同一个切换任务，不会并发启停多个
Camera Capture Session。鸿蒙的 outbound stats 在摄像头已出帧时仍可能短暂返回空值，因此不再
用发送统计阻塞该 API。
HarmonyOS 上 `setSpeakerphoneOn()` 直接调用 `flutter_webrtc` 的音频路由；建议在调用成功后
再更新页面状态，或以 `onAudioOutputDeviceChanged` 回调的 `speakerphoneOn` 为准。

### 3. 配置页面路由

在 `entry/src/main/resources/base/profile/main_pages.json` 中添加页面：

```json
{
  "src": [
    "pages/Index",
    "pages/CallPage"
  ]
}
```

### 4. 默认视频参数与首帧验收

当前版本在 HarmonyOS 上默认本地摄像头采集为 `1280×720 @ 24fps`，使用原生硬件工厂支持的
H.264 编码，顶层最大码率为 `1.7 Mbps`；simulcast 为 `180p / 360p / 720p`，其中默认订阅的
360p 中层限制为 `15fps / 450kbps`。鸿蒙端会关闭 LiveKit 的 VP8 backup codec，防止主编码已经
选择 H.264 后仍额外启动软件 VP8 编码。此前的 4K 默认值在部分鸿蒙真机上会出现
`Camera VideoOutput` 启动返回成功但不产出视频帧的问题，因此不再作为默认配置。

真机加入视频通话后，应在日志中同时确认：

```text
mediaOption ... "video":{"width":1280,"height":720,...}
[OhosCapture][OutputRoute] attempt=video ... size=1280x720 ...
[OhosCapture][FirstFrame] watchdog armed route=video timeoutMs=800
[OhosCapture][FirstFrame] received route=video input=1280x720
[OhosCapture][CameraTransform] frame=1 ...
VideoSendStream stats: ... input_fps: <大于 0> ... width: <非 0>, height: <非 0>
```

`[OhosCapture][OutputRoute] active=video` 只表示 Camera Session 的 `Start()` 返回成功，不能单独
证明已收到首帧。如果它后面始终没有 `CameraTransform frame=1`，并持续出现 `input_fps: 0`、
`width: 0`、`height: 0`、`SignalEncoderTimedOut`，故障位于鸿蒙摄像头采集到 WebRTC 的上行链路，
不是 XComponent 未创建或本地 Surface 未绑定。

当前 `dist/flutter_webrtc.har` 除了覆盖 VideoOutput 的 create/commit/start 接口明确失败，还会在 `active=video` 后启动
800ms 首帧看门狗。超时仍没有 NativeImage/WebRTC 首帧时，它会停止旧会话、关闭并重建 `CameraInput`，然后自动
切换到同尺寸 `PreviewOutput`。正常回退日志应完整包含：

```text
[OhosCapture][FirstFrame] timeout route=video timeoutMs=800; ... switching to PreviewOutput
[OhosCapture][OutputRoute] resetting CameraInput before PreviewOutput fallback
[OhosCapture][OutputRoute] CameraInput reset complete
[OhosCapture][OutputRoute] attempt=preview-fallback ...
[OhosCapture][OutputRoute] active=preview-fallback ...
[OhosCapture][FirstFrame] fallback active route=preview-fallback
[OhosCapture][FirstFrame] received route=preview-fallback ...
[OhosCapture][CameraTransform] frame=1 ...
```

回退后仍必须确认 `input_fps` 和发送宽高非零；仅出现 `fallback active` 仍不能代替首帧与 WebRTC 统计验收。
同一进程内一旦有摄像头触发该超时，SDK 会记住该设备的兼容路径；后续前后摄像头切换直接使用
`PreviewOutput`，日志会出现 `skipping VideoOutput because a previous capturer timed out`，不再每次等待看门狗。
摄像头纹理方向默认使用 HarmonyOS `NativeImage` 提供的原始变换矩阵。针对部分华为设备后置摄像头
`PreviewOutput` 在 `cameraOrientation=90` 时输出倒置画面，native 仅对
`front=0 + preview-fallback + cameraOrientation=90` 的组合附加 180° 校正；前置摄像头和
`VideoOutput` 不受影响。命中时 `CameraTransform` 应显示 `backPreviewCorrection=1`。

#### 锁屏/解锁后的本地摄像头恢复

HarmonyOS 锁屏后，系统 Camera Session 可能已经失效，但旧 native 包仍保留 `isStarted=true`。解锁时普通
`Start()` 会直接返回 `Capture session is started`，导致画面停在锁屏前最后一帧，且发送统计持续为
`input_fps: 0`、`width: 0`、`height: 0`。

当前 `flutter_webrtc.har` 已监听 `onAbilityForeground()`。应用确实经历过后台且本地视频 Track 仍为
`enabled + live` 时，SDK 会保留原 Track/RTP Sender，转到采集线程强制释放旧 Session、CameraInput 和
Output；即使旧 Session 的 `Stop()` 失败也继续清理，然后重新创建完整摄像头链路。正常日志顺序为：

```text
[ForegroundRecovery] app entered background
onAbilityForeground
[ForegroundRecovery] foreground camera restart requested tracks=1
[OhosCapture][ForegroundRecovery] START ... wasStarted=1
[OhosCapture][ForegroundRecovery] SESSION_STARTED awaitingFirstFrame=1 route=...
[OhosCapture][ForegroundRecovery] FIRST_FRAME input=1280x720 route=...
VideoSendStream stats: ... input_fps: <大于 0> ... width: <非 0>, height: <非 0>
```

`SESSION_STARTED` 只表示 Camera Session 启动调用成功；只有 `FIRST_FRAME` 才代表恢复成功。如果
VideoOutput 仍未交付首帧，原有 800ms 看门狗会继续切到 PreviewOutput。出现
`FAILED stage=start_session`、`first_frame_timeout` 或 `preview_fallback` 时，应保留完整日志继续定位。

同一版本还修复了 Stats 桥接：每个 report 会通过 `stats.pushMap(report_map)` 加入返回数组；逐字段
`reports.forEach` Info 日志已删除，只保留 Debug 级 `handleStatsReport reportCount=<n>` 摘要。因此 Dart
统计调用仍可能按固定周期执行，但不会再因桥接层为每个字段打印 Info 日志而产生数千行刷屏。

上述前台恢复和 Stats 修复都位于 `flutter_webrtc` 的 ArkTS/native 层。本次从上一发布包升级只需替换
`dist/flutter_webrtc.har`；没有因这两项修复修改 Dart 快照、`flutter.har` 或 `tgortc-*.har`。

### 5. 远端视频实时性策略与验收

HarmonyOS 的原生硬件编解码工厂支持 H.264/H.265，不支持 VP8。旧策略固定发布 VP8，并默认订阅
720p/30fps；部分真机只能使用软件 VP8 解码，解码速度持续低于网络收帧速度时，WebRTC 的
`jitterBufferDelay` 会不断增长，最终表现为对方动作约 10 秒后才显示。

当前 SDK 在 HarmonyOS 上采用以下策略：

- 发布 H.264，并禁用 VP8 backup codec，确保进入鸿蒙硬件编解码路径。
- 本地顶层限制为 720p/24fps，远端默认请求 MEDIUM（360p/15fps）层。
- 每次远端发布、订阅、入房或重连后重新应用订阅策略。
- 输出 `[MediaPolicy][RemoteStats]`，报告编码、解码器实现、帧率和统计区间内的平均排队时间。

稳定通话至少一分钟后应确认：

```text
[MediaPolicy] platform=ohos publishCodec=h264 ... remoteQuality=medium remoteMaxFps=15
[MediaPolicy] remote video configured ... quality=medium requestedFps=15 ...
[MediaPolicy][RemoteStats] ... codec=video/H264 decoder=<鸿蒙硬件解码器> ... intervalQueueMs=<稳定且不持续增长>
```

如果 `codec=video/VP8` 或 `decoder=libvpx`，表示集成工程仍在使用旧 `flutter_assets`，需要同时替换
`dist/flutter_assets` 和 `dist/flutter_assets_texture` 对应入口的完整目录。原生层另提供
`native_patches/ohos_webrtc_receive_backpressure.patch` 作为过载保护：编码帧队列达到 15 帧时丢弃
旧队列并请求关键帧，日志前缀为 `[OhosReceive][Backpressure]`。当前 `dist/flutter_webrtc.har` 已包含
该保护；自行从源码构建时仍须把补丁应用到 `ohos_webrtc`，重新生成 `libohos_webrtc.so` 并重建
`flutter_webrtc.har`。仅复制 patch 文件不会改变运行行为。

### 6. 前后摄像头切换验收

HarmonyOS 的 `RTCRtpSender.id` 在部分版本中可能为空。旧版 `flutter_webrtc.har` 会把所有 sender 都映射为固定的
`senderId`，切换摄像头时便无法找到对应的视频 sender，典型日志为：

```text
onMethodCall: rtpSenderReplaceTrack
senders length : 2
sender id : undefined
id : senderId
rtpSenderSetTrack(): sender is null
```

此时旧摄像头已释放，而新摄像头只执行到 `CameraCapturer Init`，不会继续 `Start`，表现为本地画面卡死、
`input_fps: 0`。当前 `flutter_webrtc.har` 使用原始 track ID 作为稳定的 sender fallback ID，并在
PeerConnection 生命周期内缓存该映射，确保连续多次前后切换仍能找到同一个视频 sender。

切换成功应至少确认：

```text
onMethodCall: rtpSenderReplaceTrack
getRtpSenderById cache hit: <原视频 trackId>
[VideoSurface] rebind surface=<原 surfaceId> ... oldTrack=<原 trackId> newTrack=<新 trackId>
[OhosRemoteRender][SinkAttach] surfaceId=<原 surfaceId> trackId=<新 trackId>
CameraCapturer ... Init
CameraCapturer ... Start
[OhosCapture][FirstFrame] received ...
[VideoSurface] first frame surface=<原 surfaceId> track=<新 trackId>
VideoSendStream stats: ... input_fps: <大于 0> ... width: <非 0>, height: <非 0>
```

SDK 的 `switchCamera()` 会等待 LiveKit 完成新摄像头创建、sender track 替换及启动，并保留约 300ms
的稳定窗口；切换期间的重复调用会合并。LiveKit 切换时会保留 `LocalVideoTrack` 对象，但替换它内部的
`MediaStreamTrack`；SDK 会立即将原 XComponent Surface 从已销毁的旧 track 重绑到新 track。若上行
`input_fps` 已恢复，但本地画面仍停在切换前，且日志中只有旧 track 的 `SinkDetach`、没有上述
`VideoSurface rebind`/`SinkAttach`，表示集成工程仍在使用旧 `flutter_assets`。

前后摄像头切换同时依赖 `flutter_webrtc.har` 中的 sender 映射修复和 `flutter_assets` 中的本地 Surface
重绑逻辑，升级时必须整体替换发布包四件套后卸载旧应用重装，不能只替换其中一件。

---

## 三、API 参考

### TgoRTCFlutter 类

| 方法 | 说明 | 参数 |
|------|------|------|
| `getInstance()` | 获取单例实例 | - |
| `setEventListener(listener)` | 设置事件监听器 | `TgoRTCEventListener` |
| `joinRoom(roomInfo)` | 加入房间 | `RoomInfo` |
| `leaveRoom()` | 离开房间 | - |
| `setMicrophoneEnabled(enabled)` | 开关麦克风 | `boolean` |
| `setCameraEnabled(enabled)` | 开关摄像头 | `boolean` |
| `setSpeakerphoneOn(on)` | 开关扬声器 | `boolean` |
| `switchCamera()` | 切换前后摄像头 | - |
| `invite(roomName, uids)` | 邀请参与者 | `string, string[]` |
| `getAllParticipants()` | 获取所有参与者 | - |
| `isCalling()` | 是否处于通话生命周期内 | - |
| `isSpeakerOn()` | 获取扬声器状态 | - |

`invite(roomName, uids)` 会先把本次实际接受的 UID 完整写入 SDK 状态，再通过
`onParticipantsChanged` 发送一次去重后的完整快照。新邀请成员在首次快照中即存在且
`isJoined=false`；已存在、与本机相同、同批重复或超过 `maxParticipants` 的 UID 不会重复进入快照。

### RoomInfo 接口

```typescript
interface RoomInfo {
  roomName: string        // 房间名称（必填）
  token: string           // 认证 Token（必填）
  url: string             // 服务器地址（必填）
  loginUID: string        // 登录用户 ID（必填）
  creatorUID?: string     // 创建者 ID
  maxParticipants?: number // 最大参与人数，默认 9
  rtcType?: number        // 通话类型：1=视频，0=音频
  isP2P?: boolean         // 是否点对点
  uidList?: string[]      // 邀请的用户列表
  timeout?: number        // 超时时间（秒）
  micEnabled?: boolean    // 初始麦克风状态
  cameraEnabled?: boolean // 初始摄像头状态
}
```

### TgoRTCEventListener 接口

```typescript
interface TgoRTCEventListener {
  // 连接状态变化
  onConnectStatusChanged?: (roomName: string, status: ConnectStatus, reason: string) => void
  
  // 参与者列表变化
  onParticipantsChanged?: (count: number, participants: Participant[]) => void
  
  // 本地媒体状态变化
  onLocalMediaStatusChanged?: (micEnabled: boolean, cameraEnabled: boolean) => void

  // 真实入房的远端成员离开；P2P 页面可调用 endByRemote()
  onRemoteParticipantLeft?: (roomName: string, uid: string, reason: string) => void
}
```

### Participant 接口

```typescript
interface Participant {
  uid: string
  isLocal: boolean
  // false 表示 uidList 中的受邀/占位成员，尚未实际进入 LiveKit 房间。
  isJoined: boolean
  micEnabled: boolean
  cameraEnabled: boolean
}
```

### ConnectStatus 枚举

```typescript
enum ConnectStatus {
  CONNECTING = 0,    // 连接中
  CONNECTED = 1,     // 已连接
  DISCONNECTED = 2   // 已断开
}
```

---

## 四、权限配置

在 `entry/src/main/module.json5` 中添加必要权限：

```json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
      },
      {
        "name": "ohos.permission.MICROPHONE",
        "reason": "$string:mic_permission_reason",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "inuse"
        }
      },
      {
        "name": "ohos.permission.CAMERA",
        "reason": "$string:camera_permission_reason",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "inuse"
        }
      }
    ]
  }
}
```

---

## 五、常见问题

### Q1: 找不到 @anthropic/tgortc 模块

确保：
1. `tgortc-1.0.2.har` 已放入 `har/` 目录
2. `oh-package.json5` 中路径正确
3. 执行了 `ohpm install --all` 或 Sync Project

### Q2: Flutter 视频画面不显示

按以下顺序检查：

1. 已注册 TgoRTC 插件到 FlutterEngine，并完整替换三个 HAR 和 `flutter_assets/`。
2. `attachVideoSurface` 使用的是 XComponent `onLoad` 后取得的真实 `surfaceId`。
3. 日志出现 `SinkAttach` 和 `attachVideoSurface SUCCESS`。
4. 再检查 `CameraTransform frame=1` 与非零 `input_fps`。Surface 绑定成功但采集统计始终为零时，
   不是页面布局问题，应按“默认视频参数与首帧验收”一节排查采集链路。
5. 若只在切换前后摄像头后卡死，并出现 `rtpSenderSetTrack(): sender is null`，应替换最新
   `flutter_webrtc.har`，再按“前后摄像头切换验收”一节确认 sender cache 命中和新摄像头首帧。

### Q3: 需要其他依赖吗？

是的。预编译集成需要 `tgortc-1.0.2.har`、`flutter_webrtc.har`、`flutter.har` 和完整
`flutter_assets/`。使用 Texture 入口时，把 `dist/flutter_assets_texture/` 的内容复制为集成工程中的
`flutter_assets/`，不能与默认入口的快照混用。

---

## 六、完整项目结构示例

```
YourRTCApp/
├── AppScope/
│   └── app.json5
├── entry/
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── entryability/
│   │   │   │   └── EntryAbility.ets      ← 注册插件
│   │   │   └── pages/
│   │   │       ├── Index.ets
│   │   │       └── CallPage.ets          ← 通话页面
│   │   ├── module.json5                  ← 权限配置
│   │   └── resources/
│   │       ├── base/profile/main_pages.json
│   │       └── rawfile/flutter_assets/   ← 完整 Dart 快照与资源
│   ├── build-profile.json5
│   └── oh-package.json5
├── har/
│   ├── tgortc-1.0.2.har                  ← TgoRTC ArkTS 桥接
│   ├── flutter_webrtc.har                ← WebRTC/XComponent/native 能力
│   └── flutter.har                       ← Flutter 运行时
├── build-profile.json5
└── oh-package.json5                      ← 依赖配置
```
