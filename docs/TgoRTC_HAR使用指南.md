# TgoRTC HAR 使用指南

本文档介绍如何在鸿蒙 NEXT 原生项目中集成和使用 `tgortc_library.har`。

## 前置条件

- DevEco Studio 5.0+
- HarmonyOS NEXT SDK
- 已有的鸿蒙 NEXT 项目

## 一、导入步骤

### 1. 复制 HAR 文件

将 `tgortc_library.har` 复制到你的项目中：

```
YourProject/
├── entry/
├── libs/                          ← 创建这个目录
│   └── tgortc_library.har         ← 放入 HAR 文件
├── oh-package.json5
└── build-profile.json5
```

### 2. 配置 oh-package.json5

在项目根目录的 `oh-package.json5` 中添加依赖：

```json5
{
  "name": "your_project",
  "version": "1.0.0",
  "dependencies": {
    "@anthropic/tgortc": "file:./libs/tgortc_library.har",
    "@ohos/flutter_ohos": "file:./libs/flutter.har"  // Flutter 运行时，也需要
  }
}
```

> **注意**：你还需要 `flutter.har`（Flutter 引擎），可以从 Flutter HarmonyOS SDK 中获取。

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
| `isSpeakerOn()` | 获取扬声器状态 | - |

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
1. `tgortc_library.har` 已放入 `libs/` 目录
2. `oh-package.json5` 中路径正确
3. 执行了 `ohpm install --all` 或 Sync Project

### Q2: Flutter 视频画面不显示

确保：
1. 已注册 TgoRTC 插件到 FlutterEngine
2. 使用 `@LocalStorageLink('viewId')` 获取视图 ID
3. FlutterAbility 已正确启动

### Q3: 需要其他依赖吗？

是的，需要 `@ohos/flutter_ohos`（Flutter 运行时 HAR）。这是 TgoRTC 的 peer dependency。

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
│   │       └── base/profile/main_pages.json
│   ├── build-profile.json5
│   └── oh-package.json5
├── libs/
│   ├── tgortc_library.har                ← TgoRTC SDK
│   └── flutter.har                       ← Flutter 运行时
├── build-profile.json5
└── oh-package.json5                      ← 依赖配置
```
