# TgoRTC Flutter SDK 鸿蒙 NEXT 集成指南

本指南介绍如何在鸿蒙 NEXT (HarmonyOS NEXT) 原生项目中集成 `tgortcflutter` SDK。

## 目录

- [1. 架构概述](#1-架构概述)
- [2. 集成方式选择](#2-集成方式选择)
- [3. 方式一：预编译 HAR 分发（推荐）](#3-方式一预编译-har-分发推荐)
- [4. 方式二：源码集成](#4-方式二源码集成)
- [5. API 使用示例](#5-api-使用示例)
- [6. 注意事项](#6-注意事项)

---

## 1. 架构概述

TgoRTC SDK 采用 **Flutter 视频组件 + API 桥接** 的混合架构：

```
┌─────────────────────────────────────────────────────────┐
│                    鸿蒙原生 App (ArkTS)                   │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │  顶部状态栏  │  │  控制按钮   │  │   其他原生UI    │  │
│  │   (ArkTS)   │  │   (ArkTS)  │  │     (ArkTS)     │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │              FlutterPage 视频区域                │    │
│  │         (flutter_ohos 提供的标准组件)            │    │
│  └─────────────────────────────────────────────────┘    │
│                          │                              │
│                    MethodChannel                        │
│                          │                              │
├─────────────────────────────────────────────────────────┤
│                   TgoRTC Flutter SDK                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  │
│  │RoomManager│ │Participant│ │AudioManager│ │ Bridge  │  │
│  │          │  │  Manager │  │          │  │ Layer   │  │
│  └──────────┘  └──────────┘  └──────────┘  └─────────┘  │
└─────────────────────────────────────────────────────────┘
```

**特点**：
- **视频渲染**：使用 `@ohos/flutter_ohos` 提供的 `FlutterPage` 组件
- **业务控制**：通过封装好的 ArkTS API 调用（`TgoRTCFlutter` 类）
- **事件通知**：SDK 自动将状态变化推送到原生

---

## 2. 集成方式选择

| 方式 | 适用场景 | 是否需要 Flutter SDK |
|-----|---------|-------------------|
| **预编译 HAR 分发** | 第三方快速集成，无需 Flutter 开发环境 | **否** |
| **源码集成** | 需要定制 SDK 或参与开发 | 是 |

---

## 3. 方式一：预编译 HAR 分发（推荐）

此方式下，第三方开发者**无需安装 Flutter SDK**，只需引用我们提供的预编译产物。

### 3.1 获取 SDK 文件

从发布渠道获取以下文件：

```
tgortc-sdk/
├── tgortc-1.0.2.har       # TgoRTC ArkTS 桥接
├── flutter_webrtc.har     # XComponent、摄像头和 WebRTC native 能力
├── flutter.har            # Flutter 运行时
└── flutter_assets/        # 默认入口的完整 Dart 编译产物
    ├── kernel_blob.bin
    ├── vm_snapshot_data
    ├── isolate_snapshot_data
    ├── icudtl.dat
    └── ...
```

上述四部分必须来自同一发布批次并整体更新。复制到集成工程的
`entry/src/main/resources/rawfile/flutter_assets/` 时，应复制该目录的内容，不能形成
`flutter_assets/flutter_assets/` 的重复层级。

**flutter_assets 在本项目中的位置与获取方式**（使用方常问）：

- `flutter_assets` 是 Flutter 构建产物，不是手工维护的源码目录。开发构建输出位于 `build/`；发布包中的
  `dist/flutter_assets/` 是由 SDK 提供方从该输出完整导出的交付副本。
- **生成位置**（在本项目根目录执行鸿蒙构建后）：
  - 路径：**`build/ohos/flutter_assets`**（相对于项目根目录 `tgortcflutter/`）。
- **关于构建命令**：标准 Flutter SDK 不支持 HarmonyOS/HAP 构建。要生成 `flutter_assets` 有两种方式：
  1. **使用鸿蒙版 Flutter SDK**：在项目根目录执行 `flutter build hap --debug`。参考：[OpenHarmony-TPC Flutter](https://gitcode.com/openharmony-tpc/flutter_flutter)。
  2. **使用 DevEco Studio 构建**：用 DevEco Studio 打开 `ohos/` 目录，执行 **Build → Build Hap(s)/APP(s)**，构建过程会调用 Flutter 并生成 `build/ohos/flutter_assets`（需在 DevEco 中配置好 Flutter 或鸿蒙版 Flutter）。
- **使用方如何拿到**：
  - **预编译集成**：由 SDK 提供方在发布包中附带（提供方构建后把 `build/ohos/flutter_assets` 完整复制到 **`dist/flutter_assets/`**，随 `tgortc-1.0.2.har`、`flutter_webrtc.har`、`flutter.har` 一起分发）。
  - **源码集成**：按上面任一方式在本项目根目录完成鸿蒙构建，得到 `build/ohos/flutter_assets`，再复制到鸿蒙工程的 `entry/src/main/resources/rawfile/` 下。

### 3.2 添加到项目

1. 将三个 HAR 复制到鸿蒙项目的 `har/`，并把完整 Flutter 资源复制到 rawfile：

```
your_ohos_project/
├── entry/src/main/resources/rawfile/
│   └── flutter_assets/
├── har/
│   ├── tgortc-1.0.2.har
│   ├── flutter_webrtc.har
│   └── flutter.har
└── oh-package.json5
```

2. 修改 `oh-package.json5`：

```json5
{
  "dependencies": {
    "@anthropic/tgortc": "file:./har/tgortc-1.0.2.har",
    "@ohos/flutter_ohos": "file:./har/flutter.har",
    "flutter_webrtc": "file:./har/flutter_webrtc.har"
  }
}
```

3. 复制 `flutter_assets` 到 `entry/src/main/resources/rawfile/`。（该文件夹来源见上文 3.1「flutter_assets 在本项目中的位置与获取方式」。）

### 3.3 配置 EntryAbility

**必须**在 `configureFlutterEngine` 中注册 TgoRTC 桥接插件，否则 ArkTS 侧调用 `joinRoom` 等会报 “Bridge is NOT ready” / “TgoRTC.bridge is null! Please call TgoRTC.instance.setBridge() first.”（即 Flutter 桥接未初始化）。

```typescript
// entry/src/main/ets/entryability/EntryAbility.ets
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos'
import { TgoRTCFlutter } from '@anthropic/tgortc'  // 若使用 HAR，包名以实际为准

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // 注册 TgoRTC 桥接插件，使 ArkTS 能通过 MethodChannel 调用 Flutter 侧 joinRoom 等
    flutterEngine.getPlugins()?.add(TgoRTCFlutter.getInstance())
  }
}
```

### 3.4 配置权限

在 `entry/src/main/module.json5` 中添加：

```json5
{
  "module": {
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" },
      { "name": "ohos.permission.MICROPHONE" },
      { "name": "ohos.permission.CAMERA" }
    ]
  }
}
```

### 3.5 使用 SDK

```typescript
// entry/src/main/ets/pages/CallPage.ets
import { TgoRTCFlutter, ConnectStatus } from '@anthropic/tgortc'
import { FlutterPage } from '@ohos/flutter_ohos'

// 需要通过 LocalStorage 获取 viewId（由 FlutterAbility 自动设置）
const storage = LocalStorage.getShared()

@Entry(storage)
@Component
struct CallPage {
  @LocalStorageLink('viewId') viewId: string = ''
  @State roomName: string = 'Room 101'
  @State participantCount: number = 0
  @State isMicOn: boolean = true
  @State isCameraOn: boolean = true

  async aboutToAppear() {
    // 1. 初始化 SDK
    await TgoRTCFlutter.init(getContext(this), { debug: true })

    // 2. 设置事件监听
    TgoRTCFlutter.setEventListener({
      onConnectStatusChanged: (roomName, status, reason) => {
        console.info(`Room ${roomName}: ${ConnectStatus[status]} - ${reason}`)
      },
      onParticipantsChanged: (count, participants) => {
        this.participantCount = count
        // uidList 内的受邀成员可能尚未实际入房；只能对 isJoined 为 true
        // 的远端成员开始通话计时或关闭“等待对方加入”。
        const remote = participants.find((item) => !item.isLocal && item.isJoined)
        if (remote !== undefined) {
          // markRemoteJoined(remote.uid)
        }
      }
    })

    // 3. 加入房间
    await TgoRTCFlutter.joinRoom({
      roomName: this.roomName,
      token: 'YOUR_TOKEN',
      url: 'wss://your-livekit-server.com',
      loginUID: 'user_123'
    })
  }

  build() {
    Column() {
      // 顶部信息栏
      Row() {
        Text(this.roomName).fontColor(Color.White).fontSize(20)
        Blank()
        Text(`${this.participantCount} 人`).fontColor(Color.White)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#1A1A1A')

      // 视频区域（使用 FlutterPage 组件）
      FlutterPage({ viewId: this.viewId })
        .width('100%')
        .layoutWeight(1)

      // 控制栏
      Row() {
        Button(this.isMicOn ? '静音' : '取消静音')
          .onClick(async () => {
            this.isMicOn = !this.isMicOn
            await TgoRTCFlutter.setMicrophoneEnabled(this.isMicOn)
          })

        Button(this.isCameraOn ? '关闭摄像头' : '开启摄像头')
          .onClick(async () => {
            this.isCameraOn = !this.isCameraOn
            await TgoRTCFlutter.setCameraEnabled(this.isCameraOn)
          })

        Button('挂断')
          .backgroundColor(Color.Red)
          .onClick(async () => {
            await TgoRTCFlutter.leaveRoom()
          })
      }
      .width('100%')
      .height(80)
      .justifyContent(FlexAlign.SpaceAround)
      .backgroundColor('#1A1A1A')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
```

---

## 4. 方式二：源码集成

如果你需要定制 SDK 或参与开发，请使用此方式。

### 4.1 环境要求

- **DevEco Studio**: 最新版本（支持 HarmonyOS NEXT）
- **Flutter SDK (鸿蒙版)**: 由华为或社区提供的支持鸿蒙平台的 Flutter SDK
- **鸿蒙 NEXT 真机**: 用于调试

### 4.2 克隆并配置

```bash
# 克隆 SDK
git clone https://github.com/your-repo/tgortcflutter.git

# 获取依赖
cd tgortcflutter
flutter pub get
```

### 4.3 Flutter 侧初始化

在你的 Flutter 入口 `main.dart` 中：

```dart
import 'package:flutter/material.dart';
import 'package:tgortcflutter/bridge/tgortc_ohos_bridge.dart';
import 'package:tgortcflutter/pages/video_only_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 注册鸿蒙桥接层
  TgoRTCOhosBridge.register();
  
  // 运行视频渲染页面
  runApp(const VideoOnlyApp());
}
```

### 4.4 构建 HAR

使用提供的脚本构建可分发的 HAR：

```bash
./scripts/build_har.sh release
```

输出在 `dist/` 目录。

---

## 5. API 使用示例

### 5.1 初始化

```typescript
await TgoRTCFlutter.init(context, {
  debug: true,   // 开启调试日志
  mirror: true   // 本地视频镜像
})
```

### 5.2 房间操作

```typescript
// 加入房间
await TgoRTCFlutter.joinRoom({
  roomName: 'meeting-001',
  token: 'eyJhbGciOiJIUzI1NiIs...',
  url: 'wss://livekit.example.com',
  loginUID: 'user_abc',
  micEnabled: true,
  cameraEnabled: true
})

// 离开房间
await TgoRTCFlutter.leaveRoom()
```

### 5.3 媒体控制

```typescript
// 静音/取消静音
await TgoRTCFlutter.setMicrophoneEnabled(false)

// 开关摄像头
await TgoRTCFlutter.setCameraEnabled(true)

// 切换前后摄像头
await TgoRTCFlutter.switchCamera()
// 返回时 LiveKit 已完成新摄像头创建、sender track 替换及启动，
// 本地 Surface 也已重绑到新 track；
// 切换期间的重复调用会被合并

// 扬声器开关
await TgoRTCFlutter.setSpeakerphoneOn(true)
// HarmonyOS 由 flutter_webrtc 直接切换扬声器/听筒路由
```

### 5.4 获取状态

```typescript
// 获取所有参与者
const participants = await TgoRTCFlutter.getAllParticipants()

// 是否已开始通话生命周期（包含 connecting/reconnecting，不等同于已连接）
const calling = await TgoRTCFlutter.isCalling()

// 获取扬声器状态
const isSpeakerOn = await TgoRTCFlutter.isSpeakerOn()
```

### 5.5 事件监听

```typescript
TgoRTCFlutter.setEventListener({
  onConnectStatusChanged: (roomName, status, reason) => {
    // status: 0=连接中, 1=已连接, 2=已断开
  },
  onParticipantsChanged: (count, participants) => {
    // 只有 isJoined 为 true 才是已实际进入 LiveKit 房间的远端成员。
    const remote = participants.find((item) => !item.isLocal && item.isJoined)
    if (remote !== undefined) {
      // markRemoteJoined(remote.uid)
    }
  },
  onRemoteParticipantLeft: (roomName, uid, reason) => {
    // P2P 页面可在此调用 endByRemote()
  },
  onLocalMediaStatusChanged: (micEnabled, cameraEnabled) => {
    // 本地音视频状态变化
  }
})
```

---

## 6. 注意事项

1. **Flutter 引擎生命周期**：
   - 在 `EntryAbility` 继承 `FlutterAbility`，引擎会自动初始化
   - 确保在调用 `TgoRTCFlutter.init()` 前引擎已就绪

2. **视频渲染**：
   - 使用 `@ohos/flutter_ohos` 提供的 `FlutterPage` 组件
   - 需要通过 `LocalStorage` 获取 `viewId`（由 FlutterAbility 自动设置）
   - 视频布局（网格）由 Flutter 侧控制

3. **FlutterPage 使用要点**：
   - 页面需要使用 `@Entry(storage)` 并获取 `LocalStorage.getShared()`
   - 使用 `@LocalStorageLink('viewId')` 获取 viewId
   - 示例：`FlutterPage({ viewId: this.viewId })`

4. **权限**：
   - 运行时需动态申请麦克风和摄像头权限
   - 确保 `module.json5` 中已声明权限

5. **调试**：
   - 预编译模式下，Flutter 日志会输出到系统日志
   - 使用 `hdc` 或 DevEco 的日志工具查看

6. **常见错误：Bridge / Flutter 未就绪**：
   - 若日志出现 `[TgoCall] joinRoom: Bridge is NOT ready!`、`flutterEngine: null` 或 `TgoRTC.bridge is null! Please call TgoRTC.instance.setBridge() first.`，说明 **Flutter 桥接未初始化**。
   - 原因：未在 `EntryAbility.configureFlutterEngine` 中注册 TgoRTC 插件，导致 MethodChannel 未建立。
   - 解决：在 `configureFlutterEngine(flutterEngine)` 中增加 `flutterEngine.getPlugins()?.add(TgoRTCFlutter.getInstance())`（见 3.3 节）。
