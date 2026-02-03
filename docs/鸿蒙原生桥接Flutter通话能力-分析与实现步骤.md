# 将 lib 下 TgoRTC/Manager 桥接给原生鸿蒙调用的分析与实现步骤

本文档在**不修改现有业务代码**的前提下，分析 `lib/` 下 `tgortc.dart`、`manager/` 等能力如何通过桥接方式提供给原生鸿蒙（ArkTS）调用，使「原生鸿蒙自研 UI + Flutter 底层通话逻辑」成为可能，并给出可落地的实现步骤。

---

## 一、现状与目标

### 1.1 当前架构

- **Flutter 侧**：`lib/tgortc.dart` 为入口单例，提供 `TgoRoomManager`、`TgoParticipantManager`、`TgoAudioManager`，以及实体类 `RoomInfo`、`Options`、`ConnectStatus` 等；`TgoTrackRenderer` 依赖 `flutter_webrtc` 的 `VideoTrackRenderer` 做**视频渲染**。
- **Example 的鸿蒙侧**：`example/ohos` 使用 `FlutterAbility` + `FlutterPage(viewId)`，整页 UI 均为 Flutter（Material 的 call_page/home_page），鸿蒙只负责壳与引擎生命周期。
- **目标**：原生鸿蒙**自己做 UI**，底层通话逻辑（进房、退房、静音、开关摄像头、参与者列表、连接状态等）继续使用 **Flutter 的 tgortc/manager 代码**，通过某种「桥接」从 ArkTS 调用并接收回调。

### 1.2 涉及的核心文件（需被桥接或需序列化）

| 类型 | 路径 | 作用 |
|------|------|------|
| 入口 | `lib/tgortc.dart` | `TgoRTC.instance`、`init(Options)` |
| 房间 | `lib/manager/tgo_room_manager.dart` | `joinRoom`、`leaveRoom`、连接状态监听、超时/视频统计等 |
| 参与者 | `lib/manager/tgo_participant_manager.dart` | `getLocalParticipant`、`getRemoteParticipants`、`getAllParticipants`、新参与者/离开监听、`invite`、`missed` 等 |
| 音频 | `lib/manager/tgo_audio_manager.dart` | `setSpeakerphoneOn`、`toggleSpeakerphone`、扬声器状态、设备列表等 |
| 参与者实体 | `lib/participant/tgo_participant.dart` | 本地/远端参与者封装，麦克风/摄像头开关、轨道、各类 listener |
| 视频渲染 | `lib/track/tgo_track_renderer.dart` | 依赖 `flutter_webrtc` 的 `VideoTrackRenderer`，输出 Flutter Widget |
| 实体/枚举 | `lib/entity/*.dart` | `RoomInfo`、`Options`、`ConnectStatus`、`RTCType`、`VideoInfo` 等，需与鸿蒙侧约定为 Map/JSON 或整型枚举 |

---

## 二、桥接方式选型

### 2.1 推荐：MethodChannel + EventChannel

- **MethodChannel（鸿蒙 → Dart）**：调用 `init`、`joinRoom`、`leaveRoom`、`setMicrophoneEnabled`、`setCameraEnabled`、`setSpeakerphoneOn` 等**指令型**接口，并同步或异步返回结果（如成功/失败、当前状态）。
- **EventChannel 或 MethodChannel 的「回调注册 + 事件回推」**：把 Dart 侧的 **listener**（连接状态、新参与者、参与者列表变化、本地音视频状态等）推送到鸿蒙，鸿蒙据此刷新原生 UI。

鸿蒙版 Flutter 与 Dart 的通信方式与 Android/iOS 类似：在 ArkTS 侧使用 `MethodChannel`、`EventChannel`（若 flutter_ohos 暴露）或通过自定义 Plugin 实现 `MethodCallHandler`，在 Dart 侧使用 `MethodChannel`/`EventChannel`。参考文档见 [HarmonyOS Flutter Practice: 06 — Use ArkTs to Develop Flutter Harmony Plugins](https://dev.to/shaohusuo/harmonyos-flutter-practice-06-use-arkts-to-develop-flutter-harmony-plugins-1fg8) 等。

### 2.2 Flutter 引擎的两种运行形态

| 形态 | 含义 | 适用场景 |
|------|------|----------|
| **A：保留 Flutter 页面（含视频窗）** | 鸿蒙主界面用 ArkTS，通话时打开一个 **FlutterPage**，该页内只跑「TgoRTC 逻辑 + 视频渲染」（或最小化 Flutter UI），其余列表、设置等均为鸿蒙 | 视频仍由 Flutter 的 `TgoTrackRenderer` / `flutter_webrtc` 渲染，改动最小；鸿蒙只需把「通话中」这一块做成 Flutter 嵌入。 |
| **B：Headless / 无 UI 引擎** | 启动 FlutterEngine 但不显示 Flutter UI（或仅跑一个不建树的 Dart 入口），所有通话控制与状态通过 Channel 与鸿蒙交互 | 真正「全原生 UI」，但**视频渲染**必须另做方案（见 2.3）。 |

### 2.3 视频渲染的三种路线（决定采用形态 A 还是 B）

- **路线 1（推荐、工作量最小）**  
  **形态 A**：鸿蒙仅把「通话中的视频区域」作为一块 **FlutterPage**（或一个子 View 对应 Flutter 的某 route）。该 Flutter 页内只包含 TgoRTC 的 join/leave/listener 逻辑 + `TgoTrackRenderer` 的布局，不包含列表、设置等。其它 UI（房间列表、邀请、设置、底部控制条等）全部用 ArkTS 实现，通过 **MethodChannel** 控制 Flutter 侧的 join/leave/mute/camera，通过 **EventChannel** 接收连接状态、参与者列表等，用于更新鸿蒙 UI。  
  **优点**：不改动 tgortc/manager/track 的现有实现，视频仍由 flutter_webrtc 输出。  
  **缺点**：视频窗仍是 Flutter 渲染，并非「100% 鸿蒙控件」。

- **路线 2（纯原生 UI + Flutter 仅做信令/媒体管线）**  
  **形态 B** + 在 Dart 侧对外暴露「仅逻辑」的 API（通过 Channel 封装），视频由**鸿蒙侧**用 LiveKit/WebRTC 的鸿蒙 SDK 或自研渲染（例如 XComponent + 裸数据/纹理）。Flutter 只负责：房间连接、token、参与者列表、静音/摄像头开关等状态同步。  
  **优点**：UI 完全在鸿蒙。  
  **缺点**：需在鸿蒙侧实现一套与当前 LiveKit/WebRTC 对应的媒体与渲染，或引入鸿蒙版 LiveKit SDK；tgortc 的「底层通话」不再是「全是 Flutter」，而是双端分工。

- **路线 3（技术探索）**  
  **形态 B** + Flutter 侧通过纹理/ExternalTexture 或 Platform 侧扩展，把 `flutter_webrtc` 的帧送到鸿蒙的 Surface/XComponent。  
  **优点**：理论上前端可 100% 鸿蒙、底层仍用 Flutter 的 WebRTC 管线。  
  **缺点**：依赖 livekit_client / flutter_webrtc 是否提供「帧输出」或「纹理句柄」扩展，以及鸿蒙侧接收能力，需单独调研与试验，工作量和不确定性都较大。

**实施建议**：若优先「能用、稳定、少改现有库」，先按 **路线 1（形态 A）** 做桥接；若产品强需求「全部鸿蒙控件」，再规划路线 2 或 3。

---

## 2.4 方案 A 详解：Flutter 视频组件 + API 桥接（推荐）

### 2.4.1 方案 A 架构总览

方案 A 的核心思路：**音视频展示用 Flutter 组件，其他功能通过 MethodChannel 提供 API 给鸿蒙调用**。

```
┌─────────────────────────────────────────────────────────────────────┐
│                        鸿蒙 NEXT 原生 App                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                   鸿蒙原生 UI（ArkTS）                       │    │
│  │  • 页面布局                                                 │    │
│  │  • 控制按钮（静音、摄像头、挂断）                            │    │
│  │  • 参与者列表展示                                           │    │
│  │  • 状态显示（连接中、已连接等）                              │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              │ 调用 API                              │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │              MethodChannel（桥接层）                         │    │
│  │                                                             │    │
│  │  鸿蒙 → Flutter（调用）        Flutter → 鸿蒙（事件）        │    │
│  │  • joinRoom()                 • onConnectStatusChanged      │    │
│  │  • leaveRoom()                • onParticipantsChanged       │    │
│  │  • setMicrophoneEnabled()     • onLocalMediaStatusChanged   │    │
│  │  • setCameraEnabled()                                       │    │
│  │  • setSpeakerphoneOn()                                      │    │
│  │  • invite() / missed()                                      │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                    Flutter 引擎                              │    │
│  ├────────────────────────────────────────────────────────────┤    │
│  │                                                             │    │
│  │  ┌──────────────────┐   ┌───────────────────────────────┐  │    │
│  │  │  视频组件        │   │  桥接 API                      │  │    │
│  │  │  (FlutterPage)   │   │                                │  │    │
│  │  │                  │   │  • TgoRoomManager              │  │    │
│  │  │  TgoTrackRenderer│   │  • TgoParticipantManager       │  │    │
│  │  │  ↓              │   │  • TgoAudioManager             │  │    │
│  │  │  flutter_webrtc  │   │                                │  │    │
│  │  │  ↓              │   │  所有逻辑都在 Flutter/Dart     │  │    │
│  │  │  livekit_client  │   │  鸿蒙只是"调用者"             │  │    │
│  │  │                  │   │                                │  │    │
│  │  └──────────────────┘   └───────────────────────────────┘  │    │
│  │                                                             │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.4.2 职责划分

| 模块 | 提供方 | 形式 | 说明 |
|------|--------|------|------|
| **音视频展示** | Flutter | **组件**（FlutterPage 嵌入） | TgoTrackRenderer 渲染视频画面 |
| **房间管理** | Flutter | **API**（MethodChannel） | joinRoom / leaveRoom / 连接状态 |
| **参与者管理** | Flutter | **API**（MethodChannel） | 获取参与者列表 / 新参与者事件 / invite / missed |
| **音频管理** | Flutter | **API**（MethodChannel） | 静音 / 扬声器切换 / 音频设备 |
| **摄像头控制** | Flutter | **API**（MethodChannel） | 开关摄像头 / 切换前后置 |
| **页面 UI** | 鸿蒙 | **ArkTS 控件** | 按钮、列表、状态栏等 |
| **业务逻辑** | 鸿蒙 | **ArkTS 代码** | 调用 API、处理事件、更新 UI |

### 2.4.3 Flutter 提供给鸿蒙的能力

```
┌─────────────────────────────────────────────────────────┐
│  Flutter 提供给鸿蒙的东西：                              │
│                                                         │
│  1. 一个视频组件（FlutterPage）→ 鸿蒙当控件用           │
│                                                         │
│  2. 一套 API（MethodChannel）→ 鸿蒙当 SDK 调用          │
│     • joinRoom(roomInfo)                                │
│     • leaveRoom()                                       │
│     • setMicrophoneEnabled(bool)                        │
│     • setCameraEnabled(bool)                            │
│     • setSpeakerphoneOn(bool)                           │
│     • invite(uids)                                      │
│     • getAllParticipants() → List<Participant>          │
│     • ...                                               │
│                                                         │
│  3. 事件回调（MethodChannel 反向调用）                   │
│     • onConnectStatusChanged                            │
│     • onParticipantsChanged                             │
│     • onLocalMediaStatusChanged                         │
│     • ...                                               │
└─────────────────────────────────────────────────────────┘
```

### 2.4.4 页面布局示意

```
┌─────────────────────────────────────────────────────────────────────┐
│                    鸿蒙原生页面 CallPage.ets                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  顶部状态栏（ArkTS）：房间名、参与人数                          │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                                                              │  │
│  │              FlutterPage（视频区域）                          │  │
│  │           承载 Flutter 的 VideoWidget                         │  │
│  │           用法：FlutterPage({ viewId: this.viewId })         │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  底部控制栏（ArkTS）：静音、摄像头、挂断按钮                     │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.4.5 代码示例：鸿蒙侧原生通话页面 (ArkTS)

```typescript
// entry/src/main/ets/pages/CallPage.ets

import { FlutterPage, FlutterManager } from '@ohos/flutter_ohos'
import { MethodChannel, MethodResult } from '@ohos/flutter_ohos'
import common from '@ohos.app.ability.common'

@Entry
@Component
struct CallPage {
  private context = getContext(this) as common.UIAbilityContext
  
  // Flutter 视图 ID
  @State viewId: string = ''
  
  // 通话状态
  @State isConnected: boolean = false
  @State isMicEnabled: boolean = true
  @State isCameraEnabled: boolean = true
  @State participantCount: number = 0
  @State roomName: string = ''
  
  // MethodChannel 用于与 Flutter 通信
  private channel: MethodChannel | null = null
  
  aboutToAppear() {
    this.initFlutter()
  }
  
  async initFlutter() {
    // 获取 Flutter 引擎
    let engine = FlutterManager.getInstance().getEngine()
    
    // 创建 MethodChannel
    this.channel = new MethodChannel(engine.dartExecutor, 'com.tgortc/bridge')
    
    // 监听 Flutter 发来的事件
    this.channel.setMethodCallHandler((call, result) => {
      switch (call.method) {
        case 'onConnectStatusChanged':
          this.handleConnectStatus(call.arguments)
          result.success(null)
          break
        case 'onParticipantsChanged':
          this.participantCount = call.arguments['count']
          result.success(null)
          break
        case 'onLocalMediaStatusChanged':
          this.isMicEnabled = call.arguments['micEnabled']
          this.isCameraEnabled = call.arguments['cameraEnabled']
          result.success(null)
          break
        default:
          result.notImplemented()
      }
    })
    
    // 获取 viewId 用于显示 FlutterPage
    this.viewId = engine.getViewId()
  }
  
  handleConnectStatus(args: object) {
    let status = args['status'] as number
    this.roomName = args['roomName'] as string
    this.isConnected = (status === 1) // 1 = connected
  }
  
  // 调用 Flutter 的方法
  async joinRoom() {
    await this.channel?.invokeMethod('joinRoom', {
      'roomName': 'test-room',
      'token': 'your-token',
      'url': 'wss://your-livekit-server',
      'loginUID': 'user-123',
      'creatorUID': 'user-456',
      'micEnabled': true,
      'cameraEnabled': true
    })
  }
  
  async toggleMic() {
    await this.channel?.invokeMethod('setMicrophoneEnabled', !this.isMicEnabled)
  }
  
  async toggleCamera() {
    await this.channel?.invokeMethod('setCameraEnabled', !this.isCameraEnabled)
  }
  
  async hangUp() {
    await this.channel?.invokeMethod('leaveRoom', null)
    this.context.terminateSelf()
  }
  
  build() {
    Column() {
      // ========== 顶部状态栏（ArkTS 原生控件）==========
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(this.isConnected ? '#10B981' : '#FBBF24')
        
        Text(this.roomName || '连接中...')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .margin({ left: 8 })
        
        Blank()
        
        Text(`${this.participantCount} 人`)
          .fontSize(14)
          .fontColor('#FFFFFF80')
      }
      .width('100%')
      .height(60)
      .padding({ left: 20, right: 20 })
      .backgroundColor('#1A1A3E')
      
      // ========== 视频区域（Flutter 控件）==========
      FlutterPage({ viewId: this.viewId })
        .width('100%')
        .layoutWeight(1)
      
      // ========== 底部控制栏（ArkTS 原生控件）==========
      Row() {
        Column() {
          Image(this.isMicEnabled ? $r('app.media.mic_on') : $r('app.media.mic_off'))
            .width(28).height(28)
          Text(this.isMicEnabled ? '静音' : '取消静音')
            .fontSize(12).fontColor('#FFFFFF80').margin({ top: 4 })
        }.onClick(() => this.toggleMic()).width(80)
        
        Column() {
          Image(this.isCameraEnabled ? $r('app.media.camera_on') : $r('app.media.camera_off'))
            .width(28).height(28)
          Text(this.isCameraEnabled ? '关闭摄像头' : '打开摄像头')
            .fontSize(12).fontColor('#FFFFFF80').margin({ top: 4 })
        }.onClick(() => this.toggleCamera()).width(80)
        
        Column() {
          Button().width(56).height(56).borderRadius(28).backgroundColor('#EF4444')
          Text('挂断').fontSize(12).fontColor('#FFFFFF80').margin({ top: 4 })
        }.onClick(() => this.hangUp()).width(80)
      }
      .width('100%')
      .height(120)
      .justifyContent(FlexAlign.SpaceEvenly)
      .backgroundColor('#0F0F23')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0F0F23')
  }
}
```

### 2.4.6 代码示例：Flutter 侧桥接层

```dart
// lib/bridge/tgortc_ohos_bridge.dart

import 'package:flutter/services.dart';
import 'package:tgortcflutter/tgortc.dart';

/// TgoRTC 鸿蒙桥接层
class TgoRTCOhosBridge {
  static const MethodChannel _channel = MethodChannel('com.tgortc/bridge');
  
  /// 注册桥接（在 main.dart 中调用）
  static void register() {
    _channel.setMethodCallHandler(_handleMethodCall);
    _setupEventForwarding();
  }
  
  /// 处理鸿蒙侧的方法调用
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'init':
        return _init(call.arguments);
      case 'joinRoom':
        return _joinRoom(call.arguments);
      case 'leaveRoom':
        return _leaveRoom();
      case 'setMicrophoneEnabled':
        return _setMicrophoneEnabled(call.arguments);
      case 'setCameraEnabled':
        return _setCameraEnabled(call.arguments);
      case 'setSpeakerphoneOn':
        return _setSpeakerphoneOn(call.arguments);
      default:
        throw PlatformException(code: 'NOT_IMPLEMENTED');
    }
  }
  
  static Future<void> _init(Map<dynamic, dynamic> args) async {
    TgoRTC.instance.init(Options()
      ..debug = args['debug'] ?? true
      ..mirror = args['mirror'] ?? true);
  }
  
  static Future<void> _joinRoom(Map<dynamic, dynamic> args) async {
    final roomInfo = RoomInfo(
      args['roomName'],
      args['token'],
      args['url'],
      args['loginUID'],
      args['creatorUID'],
    );
    roomInfo.uidList = List<String>.from(args['uidList'] ?? []);
    
    await TgoRTC.instance.roomManager.joinRoom(
      roomInfo,
      micEnabled: args['micEnabled'] ?? true,
      cameraEnabled: args['cameraEnabled'] ?? true,
    );
  }
  
  static Future<void> _leaveRoom() async {
    await TgoRTC.instance.roomManager.leaveRoom();
  }
  
  static Future<void> _setMicrophoneEnabled(bool enabled) async {
    await TgoRTC.instance.participantManager
        .getLocalParticipant()
        .setMicrophoneEnabled(enabled);
  }
  
  static Future<void> _setCameraEnabled(bool enabled) async {
    await TgoRTC.instance.participantManager
        .getLocalParticipant()
        .setCameraEnabled(enabled);
  }
  
  static Future<void> _setSpeakerphoneOn(bool on) async {
    await TgoRTC.instance.audioManager.setSpeakerphoneOn(on);
  }
  
  /// 设置事件转发：把 TgoRTC 的事件推给鸿蒙
  static void _setupEventForwarding() {
    // 连接状态变化
    TgoRTC.instance.roomManager.addConnectListener((roomName, status, reason) {
      _channel.invokeMethod('onConnectStatusChanged', {
        'roomName': roomName,
        'status': status.index,
        'reason': reason,
      });
    });
    
    // 新参与者加入
    TgoRTC.instance.participantManager.addNewParticipantListener((participant) {
      _notifyParticipantsChanged();
      participant.addLeaveListener(() => _notifyParticipantsChanged());
    });
  }
  
  static void _notifyParticipantsChanged() {
    final participants = TgoRTC.instance.participantManager.getAllParticipants();
    _channel.invokeMethod('onParticipantsChanged', {
      'count': participants.length,
      'participants': participants.map((p) => {
        'uid': p.uid,
        'isLocal': p.isLocal,
        'micEnabled': p.getMicrophoneEnabled(),
        'cameraEnabled': p.getCameraEnabled(),
      }).toList(),
    });
  }
}
```

### 2.4.7 代码示例：Flutter 侧纯视频页面

```dart
// lib/pages/video_only_page.dart

import 'package:flutter/material.dart';
import 'package:tgortcflutter/tgortc.dart';
import 'package:tgortcflutter/track/tgo_track_renderer.dart';
import 'package:livekit_client/livekit_client.dart';

/// 纯视频页面：只显示视频网格，无其他 UI
/// 供鸿蒙原生页面通过 FlutterPage 嵌入
class VideoOnlyPage extends StatefulWidget {
  const VideoOnlyPage({super.key});

  @override
  State<VideoOnlyPage> createState() => _VideoOnlyPageState();
}

class _VideoOnlyPageState extends State<VideoOnlyPage> {
  List<TgoParticipant> _participants = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    TgoRTC.instance.roomManager.addConnectListener((_, status, __) {
      if (status == ConnectStatus.connected) {
        _updateParticipants();
      }
    });

    TgoRTC.instance.participantManager.addNewParticipantListener((p) {
      p.addJoinedListener(() => _updateParticipants());
      p.addLeaveListener(() => _updateParticipants());
      p.addCameraStatusListener((_) => _updateParticipants());
      _updateParticipants();
    });
  }

  void _updateParticipants() {
    if (!mounted) return;
    setState(() {
      _participants = TgoRTC.instance.participantManager.getAllParticipants();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_participants.isEmpty) {
      return Container(
        color: const Color(0xFF0F0F23),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final count = _participants.length;
    final crossAxisCount = count <= 1 ? 1 : count <= 4 ? 2 : 3;

    return Container(
      color: const Color(0xFF0F0F23),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: count == 1 ? 3 / 4 : 1,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          return _buildVideoTile(_participants[index]);
        },
      ),
    );
  }

  Widget _buildVideoTile(TgoParticipant participant) {
    final renderer = TgoTrackRenderer(
      source: TrackSource.camera,
      fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
    renderer.setParticipant(participant);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFF1A1A3E),
        child: Stack(
          fit: StackFit.expand,
          children: [
            participant.getCameraEnabled()
                ? renderer.build()
                : Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: participant.isLocal
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF10B981),
                      ),
                      child: Center(
                        child: Text(
                          participant.uid.isNotEmpty
                              ? participant.uid[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  participant.isLocal ? '我' : participant.uid,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            if (!participant.getMicrophoneEnabled())
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.mic_off, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

### 2.4.8 代码示例：Flutter 入口文件

```dart
// lib/main.dart（鸿蒙专用入口）

import 'package:flutter/material.dart';
import 'package:tgortcflutter/tgortc.dart';
import 'bridge/tgortc_ohos_bridge.dart';
import 'pages/video_only_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 注册鸿蒙桥接
  TgoRTCOhosBridge.register();

  // 初始化 TgoRTC
  TgoRTC.instance.init(Options()..debug = true..mirror = true);

  runApp(const VideoOnlyApp());
}

class VideoOnlyApp extends StatelessWidget {
  const VideoOnlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const VideoOnlyPage(),
    );
  }
}
```

### 2.4.9 目录结构

```
tgortcflutter/
├── lib/
│   ├── tgortc.dart                    # SDK 入口（不改）
│   ├── manager/                       # 原有 manager（不改）
│   ├── participant/                   # 原有 participant（不改）
│   ├── track/                         # 原有 track（不改）
│   ├── entity/                        # 原有 entity（不改）
│   ├── bridge/
│   │   └── tgortc_ohos_bridge.dart    # 新增：鸿蒙桥接层
│   └── pages/
│       └── video_only_page.dart       # 新增：纯视频页面
│
└── example/
    └── ohos/
        └── entry/src/main/ets/
            └── pages/
                └── CallPage.ets       # 新增：鸿蒙原生通话页
```

### 2.4.10 方案 A 关键要点

| 问题 | 答案 |
|------|------|
| FlutterPage 是什么？ | ArkTS 组件，用于在鸿蒙原生页面中**嵌入 Flutter 视图** |
| FlutterPage 是控件吗？ | **是**，可设置宽高、布局，像普通 ArkTS 控件一样使用 |
| 视频怎么加载？ | Flutter 的 `TgoTrackRenderer.build()` 返回 Widget → 显示在 FlutterPage 中 |
| 鸿蒙怎么控制通话？ | 通过 **MethodChannel** 调用 Flutter 的 joinRoom/leaveRoom 等 |
| Flutter 怎么通知鸿蒙？ | 通过 **MethodChannel.invokeMethod** 把事件推给鸿蒙 |
| 需要 Flutter 引擎吗？ | **需要**，Dart 代码必须运行在 Flutter 引擎上 |
| App 体积增加多少？ | 约 +15-20MB（Flutter 引擎 + Dart 代码） |

---

## 2.5 方案 B 详解：鸿蒙 NEXT 原生 UI 渲染音视频（100% 纯鸿蒙控件）

若选择**形态 B（100% 鸿蒙原生 UI）**，需要了解鸿蒙 NEXT 的原生音视频渲染体系。以下是基于华为官方文档和社区实践整理的技术方案。

**注意**：方案 B 需要改造 flutter_webrtc 的 OHOS 原生层，工作量较大。如无「纯血鸿蒙认证」等硬性要求，建议优先采用方案 A。

### 2.5.1 视频渲染核心组件：XComponent

**XComponent** 是鸿蒙 NEXT 上用于自定义渲染（视频、游戏、相机预览等）的核心组件。

#### XComponent 基础用法

```typescript
// ArkTS 页面中声明 XComponent
@Entry
@Component
struct VideoCallPage {
  private xComponentController: XComponentController = new XComponentController()
  private surfaceId: string = ''

  build() {
    Column() {
      // 视频渲染区域
      XComponent({
        id: 'remoteVideo',
        type: XComponentType.SURFACE,  // 必须是 SURFACE 类型
        controller: this.xComponentController
      })
      .onLoad(() => {
        // 获取 surfaceId，用于绑定视频输出
        this.surfaceId = this.xComponentController.getXComponentSurfaceId()
        console.log('XComponent surfaceId: ' + this.surfaceId)
      })
      .width('100%')
      .height('50%')
      
      // 控制按钮等其他 ArkTS UI
      Row() {
        Button('静音').onClick(() => { /* 通过 MethodChannel 调用 Flutter */ })
        Button('挂断').onClick(() => { /* 通过 MethodChannel 调用 Flutter */ })
      }
    }
  }
}
```

#### XComponent 关键特性

| 特性 | 说明 |
|------|------|
| **类型** | 必须设置为 `XComponentType.SURFACE` |
| **surfaceId** | 通过 `XComponentController.getXComponentSurfaceId()` 获取 |
| **用途** | 承载视频流、相机预览、OpenGL 渲染等 |
| **限制** | 不支持 DevEco 预览，需真机测试 |

### 2.5.2 视频数据流架构

鸿蒙 NEXT 的视频渲染遵循以下数据流：

```
┌─────────────────────────────────────────────────────────────────────┐
│                         视频数据来源                                  │
├─────────────────────────────────────────────────────────────────────┤
│  1. 本地摄像头：CameraKit → PreviewOutput → surfaceId               │
│  2. 远端视频流：RTC SDK 解码 → surfaceId                             │
│  3. 视频文件：AVPlayer → surfaceId                                   │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Graphic Framework（图形框架）                      │
│  surfaceId → BufferQueue → 合成 → 显示 HDI                           │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         XComponent 显示                              │
│  ArkTS UI 中的 XComponent 组件渲染视频画面                            │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.5.3 本地摄像头预览：CameraKit

本地摄像头预览使用鸿蒙原生 CameraKit，**不依赖 Flutter**。

```typescript
// 简化流程示意（需在实际代码中处理权限、错误等）
import { camera } from '@kit.CameraKit'

class LocalCameraPreview {
  private cameraManager: camera.CameraManager
  private cameraInput: camera.CameraInput
  private previewOutput: camera.PreviewOutput
  private session: camera.PhotoSession

  async startPreview(surfaceId: string) {
    // 1. 获取相机管理器
    this.cameraManager = camera.getCameraManager(getContext())
    
    // 2. 获取相机列表，选择前置/后置
    let cameras = this.cameraManager.getSupportedCameras()
    let cameraDevice = cameras[0] // 选择第一个摄像头
    
    // 3. 创建相机输入流
    this.cameraInput = this.cameraManager.createCameraInput(cameraDevice)
    await this.cameraInput.open()
    
    // 4. 创建预览输出流，绑定到 XComponent 的 surfaceId
    let profile = this.cameraManager.getSupportedOutputCapability(cameraDevice).previewProfiles[0]
    this.previewOutput = this.cameraManager.createPreviewOutput(profile, surfaceId)
    
    // 5. 创建会话并启动
    this.session = this.cameraManager.createSession(camera.SceneMode.NORMAL_PHOTO)
    this.session.beginConfig()
    this.session.addInput(this.cameraInput)
    this.session.addOutput(this.previewOutput)
    await this.session.commitConfig()
    await this.session.start()
  }
  
  async stopPreview() {
    await this.session?.stop()
    await this.session?.release()
    await this.cameraInput?.close()
  }
}
```

### 2.5.4 远端视频渲染：三种方案

#### 方案 A：使用鸿蒙原生 RTC SDK（推荐）

已有多家厂商提供鸿蒙 NEXT 原生 RTC SDK：

| SDK | 状态 | 包名/文档 |
|-----|------|----------|
| **声网 Agora** | 已发布 v4.4.2 | `@shengwang/rtc-full` / [声网文档中心](https://doc.shengwang.cn/doc/rtc/harmonyos/overview/release-notes) |
| **火山引擎** | 已适配 | [火山引擎 RTC 文档](https://www.volcengine.com/docs/6348/1433812) |
| **融云** | RTC 即将上线 | 鸿蒙生态伙伴 SDK 市场 |
| **百家云** | 已支持 | [BRTC 开发者中心](https://docs.baijiayun.com/rtc/release/HarmonyOS.html) |

**集成方式**：
1. 在 oh-package.json5 中添加 SDK 依赖
2. 调用 SDK 的「加入房间、发布/订阅流」等 API
3. SDK 内部会把解码后的视频帧输出到你传入的 surfaceId
4. 鸿蒙侧完全自主，无需 Flutter 参与视频渲染

**与 Flutter tgortc 的关系**：
- **可完全弃用** Flutter 的 tgortc，改用鸿蒙 SDK
- **或做状态桥接**：Flutter 侧仍保留 tgortc 做房间/参与者管理，鸿蒙 SDK 仅负责音视频收发与渲染（需要两套 SDK 状态同步，复杂度较高）

#### 方案 B：NAPI + OpenGL 自渲染 YUV 帧

如果需要从 Flutter 侧获取解码后的视频帧（YUV/NV12），可通过 NAPI 在 C++ 层渲染。

**技术要点**（参考 [NdkXComponent 示例](https://gitee.com/harmonyos_samples/ndk-xcomponent)）：

1. **XComponent 获取 NativeWindow**
   ```cpp
   // C++ NAPI 层
   #include <native_window/external_window.h>
   
   // 从 XComponent 获取 NativeWindow
   OHNativeWindow* nativeWindow = OH_NativeXComponent_GetNativeWindow(component);
   ```

2. **创建 EGL 环境**
   ```cpp
   // 初始化 EGL
   EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
   eglInitialize(display, nullptr, nullptr);
   // 创建 EGLSurface、EGLContext 等
   ```

3. **渲染 YUV 帧**
   ```cpp
   // 使用 OpenGL Shader 将 YUV 转换为 RGB 并渲染
   // Y、U、V 分别作为纹理上传
   // 在 Fragment Shader 中做 YUV→RGB 转换
   ```

4. **帧数据传输**
   - 从 Flutter 侧通过 MethodChannel 传输帧数据（base64 或二进制）—— **性能差，不推荐**
   - 或通过 **共享内存**（需要 Flutter 侧支持）—— 复杂度高
   - 或 **魔改 flutter_webrtc**，让其输出到鸿蒙提供的 surfaceId —— 需深入改库

#### 方案 C：Flutter External Texture 反向导出（技术探索）

当前 fluttertpc_flutter_webrtc 使用 Flutter 的 **External Texture** 机制：

```
WebRTC 解码帧 → Flutter 引擎 Texture Registry → surfaceId（给 Flutter 用）→ Dart Texture Widget
```

**理论上**可以让该 surfaceId 指向鸿蒙 XComponent 的 Surface，但：
- 需要魔改 flutter_webrtc 的 OHOS 原生层
- 需要 Flutter 引擎支持「外部提供 Surface」的能力
- **工作量和不确定性都很大**，不建议优先尝试

### 2.5.5 音频处理：Audio Kit

鸿蒙 NEXT 的音频通过 **Audio Kit** 处理，主要类包括：

| 类 | 用途 |
|----|------|
| **AudioRenderer** | 音频播放/渲染，用于播放远端音频流 |
| **AudioCapturer** | 音频采集，用于录制本地麦克风 |
| **AudioManager** | 音频管理，控制音量、扬声器/听筒切换等 |

若使用鸿蒙原生 RTC SDK，音频由 SDK 内部处理，无需手动操作 Audio Kit。

### 2.5.6 方案 B 的实现路径（针对本项目 tgortcflutter SDK）

本项目 tgortcflutter 本身就是 RTC SDK，目标是适配鸿蒙 NEXT 原生 UI。核心挑战是：**如何让 Flutter 的 livekit_client/flutter_webrtc 解码后的视频帧，渲染到鸿蒙原生的 XComponent 上？**

#### 当前 flutter_webrtc 的视频渲染机制

```
┌─────────────────────────────────────────────────────────────────────┐
│                   当前 fluttertpc_flutter_webrtc 机制                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  WebRTC 解码帧                                                        │
│       │                                                              │
│       ▼                                                              │
│  Flutter Texture Registry                                            │
│       │                                                              │
│       ▼ surfaceId（给 Flutter 引擎用）                                │
│       │                                                              │
│       ▼                                                              │
│  Dart 层 Texture Widget / VideoTrackRenderer                         │
│                                                                      │
│  问题：surfaceId 是 Flutter 引擎内部的，鸿蒙 XComponent 无法使用       │
└─────────────────────────────────────────────────────────────────────┘
```

#### 路径 2b-1：改造 flutter_webrtc 支持外部 Surface（推荐）

**目标**：让 flutter_webrtc 的 OHOS 原生层支持「把视频帧输出到外部传入的 surfaceId」。

**改造思路**：

```
┌─────────────────────────────────────────────────────────────────────┐
│                        改造后的机制                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  鸿蒙原生 UI                                                          │
│       │                                                              │
│       ▼ 创建 XComponent，获取 surfaceId                              │
│       │                                                              │
│       ▼ 通过 MethodChannel 把 surfaceId 传给 Flutter                 │
│                                                                      │
│  Flutter/Dart 桥接层                                                 │
│       │                                                              │
│       ▼ 调用 flutter_webrtc 的新接口：setExternalSurface(surfaceId)  │
│                                                                      │
│  flutter_webrtc OHOS 原生层（需改造）                                  │
│       │                                                              │
│       ▼ WebRTC 解码帧 → 输出到传入的 surfaceId                        │
│       │                                                              │
│       ▼                                                              │
│  鸿蒙 XComponent 显示                                                 │
└─────────────────────────────────────────────────────────────────────┘
```

**需要改造的代码位置**：

1. **fluttertpc_flutter_webrtc 的 OHOS 原生层**：
   - 增加 `setExternalSurfaceId(surfaceId: string)` 接口
   - 修改 WebRTC VideoSink 的输出目标，从 Flutter Texture Registry 改为外部 Surface
   - 需要研究 ohos_webrtc 的 VideoRenderer 实现

2. **Dart 层增加 API**：
   ```dart
   // 新增接口
   class RTCVideoRenderer {
     // 原有：渲染到 Flutter Texture Widget
     int get textureId;
     
     // 新增：设置外部 Surface，用于鸿蒙原生渲染
     Future<void> setExternalSurfaceId(String surfaceId);
   }
   ```

3. **MethodChannel 桥接**：
   - 鸿蒙侧把 XComponent 的 surfaceId 通过 Channel 传给 Dart
   - Dart 调用 `setExternalSurfaceId` 设置输出目标

**工作量评估**：高，需要深入理解 flutter_webrtc 和 ohos_webrtc 的原生实现。

#### 路径 2b-2：帧数据回调 + NAPI 渲染

**目标**：在 flutter_webrtc 原生层增加帧数据回调，鸿蒙侧接收帧后通过 OpenGL 渲染。

**改造思路**：

```
┌─────────────────────────────────────────────────────────────────────┐
│  flutter_webrtc OHOS 原生层（需改造）                                  │
│       │                                                              │
│       ▼ WebRTC 解码得到 VideoFrame（YUV/NV12）                        │
│       │                                                              │
│       ▼ 通过回调接口把帧数据传给鸿蒙侧                                  │
│                                                                      │
│  鸿蒙 NAPI 层                                                         │
│       │                                                              │
│       ▼ 接收 YUV 帧数据                                              │
│       │                                                              │
│       ▼ 通过 OpenGL Shader 做 YUV→RGB 转换                           │
│       │                                                              │
│       ▼ 渲染到 XComponent 的 NativeWindow                            │
└─────────────────────────────────────────────────────────────────────┘
```

**需要改造的代码**：

1. **flutter_webrtc OHOS 原生层**：
   ```cpp
   // 增加帧数据回调接口
   void setVideoFrameCallback(VideoFrameCallback callback);
   
   // VideoSink 的 onFrame 中调用回调
   void onFrame(const webrtc::VideoFrame& frame) {
     // 把 frame 数据传给回调
     if (callback_) {
       callback_(frame.video_frame_buffer(), frame.width(), frame.height());
     }
   }
   ```

2. **鸿蒙 NAPI 渲染模块**：
   - 参考 [NdkXComponent 示例](https://gitee.com/harmonyos_samples/ndk-xcomponent) 实现 YUV 渲染
   - 接收帧数据，上传到 OpenGL 纹理，渲染到 XComponent

**性能考虑**：
- 帧数据拷贝有开销，需要优化（如共享内存）
- 30fps 1080p 的 YUV 数据量约 50MB/s

**工作量评估**：高，需要 NAPI/OpenGL 开发能力。

#### 路径 2b-3：共享 Surface 方案（技术探索）

**目标**：让 Flutter Texture Registry 使用的 Surface 实际上就是鸿蒙 XComponent 的 Surface。

**思路**：
1. 研究 Flutter OHOS 引擎的 Texture Registry 实现
2. 看是否能在注册纹理时传入外部 Surface 而非引擎内部创建
3. 这可能需要改 Flutter 引擎本身

**风险**：需要深入 Flutter 引擎源码，改动大，不确定性高。

### 2.5.7 方案 B 实现路径对比

| 路径 | 描述 | 改动范围 | 工作量 | 推荐度 |
|------|------|----------|--------|--------|
| **2b-1** | 改造 flutter_webrtc 支持外部 Surface | flutter_webrtc OHOS 原生层 + Dart API | 高 | ⭐⭐⭐⭐ |
| **2b-2** | 帧数据回调 + NAPI OpenGL 渲染 | flutter_webrtc + 新建 NAPI 渲染模块 | 高 | ⭐⭐⭐ |
| **2b-3** | 共享 Surface（改 Flutter 引擎） | Flutter 引擎 | 非常高 | ⭐ |

### 2.5.8 路径 2b-1 的详细实现步骤

以下是路径 2b-1（改造 flutter_webrtc 支持外部 Surface）的详细步骤：

#### 阶段一：研究 fluttertpc_flutter_webrtc 的 OHOS 原生实现

1. **克隆并阅读源码**
   - 克隆 [fluttertpc_flutter_webrtc](https://gitcode.com/openharmony-sig/fluttertpc_flutter_webrtc) 仓库
   - 定位 OHOS 平台的原生代码目录（通常在 `ohos/` 或 `src/ohos/`）
   - 找到 VideoRenderer 相关的实现类

2. **理解当前渲染流程**
   - 找到 WebRTC VideoSink 的实现
   - 理解如何获取 Flutter Texture Registry 的 surfaceId
   - 理解如何把解码帧输出到该 Surface

3. **研究 ohos_webrtc 的渲染 API**
   - 查看 [ohos_webrtc](https://gitee.com/openharmony-sig/ohos_webrtc) 仓库
   - 了解鸿蒙原生 WebRTC 的 VideoRenderer 接口
   - 确认是否支持输出到任意 Surface

#### 阶段二：改造 flutter_webrtc OHOS 原生层

4. **增加外部 Surface 接口**
   ```cpp
   // 伪代码示意
   class FlutterWebRTCPlugin {
   public:
     // 新增：设置外部 Surface（由鸿蒙 XComponent 提供）
     void setExternalSurfaceId(const std::string& surfaceId);
     
   private:
     std::string externalSurfaceId_;
     bool useExternalSurface_ = false;
   };
   ```

5. **修改 VideoSink 输出目标**
   ```cpp
   void VideoRenderer::onFrame(const webrtc::VideoFrame& frame) {
     if (useExternalSurface_ && !externalSurfaceId_.empty()) {
       // 输出到外部 Surface
       renderToExternalSurface(frame, externalSurfaceId_);
     } else {
       // 原有逻辑：输出到 Flutter Texture
       renderToFlutterTexture(frame);
     }
   }
   ```

6. **实现 renderToExternalSurface**
   - 通过 surfaceId 获取 NativeWindow
   - 把视频帧写入该 NativeWindow

#### 阶段三：Dart 层 API 封装

7. **增加 Dart 侧接口**
   ```dart
   // lib/src/native/rtc_video_renderer_impl.dart
   class RTCVideoRendererNative extends RTCVideoRenderer {
     static const MethodChannel _channel = MethodChannel('FlutterWebRTC.Method');
     
     /// 设置外部 Surface，用于鸿蒙原生渲染
     /// [surfaceId] 由鸿蒙 XComponent 提供
     Future<void> setExternalSurfaceId(String surfaceId) async {
       await _channel.invokeMethod('setExternalSurfaceId', {
         'rendererId': textureId,
         'surfaceId': surfaceId,
       });
     }
   }
   ```

8. **处理 MethodChannel 调用**
   - 在 OHOS 原生层的 MethodChannel Handler 中处理 `setExternalSurfaceId`
   - 调用 C++ 层的 `setExternalSurfaceId` 方法

#### 阶段四：tgortcflutter 桥接层集成

9. **在 TgoRTC 桥接层增加接口**
   ```dart
   // lib/bridge/tgortc_ohos_bridge.dart
   class TgoRTCOhosBridge {
     static const MethodChannel _channel = MethodChannel('com.tgortc/bridge');
     
     /// 设置远端视频渲染到鸿蒙 XComponent
     /// [uid] 参与者 ID
     /// [surfaceId] 鸿蒙 XComponent 的 surfaceId
     static Future<void> setRemoteVideoSurface(String uid, String surfaceId) async {
       // 获取该 uid 的 VideoTrack
       var participant = TgoRTC.instance.participantManager.getParticipantByUid(uid);
       var videoTrack = participant?.getVideoTrack();
       if (videoTrack != null) {
         var renderer = RTCVideoRenderer();
         await renderer.initialize();
         videoTrack.addRenderer(renderer);
         await renderer.setExternalSurfaceId(surfaceId);
       }
     }
   }
   ```

10. **鸿蒙侧调用**
    ```typescript
    // ArkTS
    // 1. 创建 XComponent
    XComponent({ id: 'remoteVideo', type: XComponentType.SURFACE, controller: xController })
    .onLoad(() => {
      let surfaceId = xController.getXComponentSurfaceId()
      
      // 2. 通过 MethodChannel 把 surfaceId 传给 Flutter
      channel.invokeMethod('setRemoteVideoSurface', { 
        uid: 'remote-user-id', 
        surfaceId: surfaceId 
      })
    })
    ```

#### 阶段五：验证与优化

11. **功能验证**
    - 验证视频帧能正确渲染到 XComponent
    - 验证多路视频的独立渲染
    - 验证视频尺寸变化时的自适应

12. **性能优化**
    - 确保帧率稳定
    - 检查内存占用
    - 优化延迟

### 2.5.9 关键决策点

在实施方案 B 之前，需要确认：

1. **fluttertpc_flutter_webrtc 的 OHOS 原生层是否可以获取源码？**
   - 若可以 → 走路径 2b-1 或 2b-2
   - 若只有二进制包 → 需要联系维护者或 Fork 自己的版本

2. **是否有 NAPI/C++ 和 OpenGL 开发能力？**
   - 路径 2b-1 和 2b-2 都需要原生开发能力

3. **时间和资源评估**
   - 路径 2b-1 预估需要 2-4 周（熟悉代码 + 改造 + 测试）
   - 路径 2b-2 可能更长（需要额外开发渲染模块）

4. **是否可以先用方案 A 验证业务逻辑？**
   - 建议先用方案 A（FlutterPage 嵌入视频窗）跑通完整流程
   - 再逐步改造为方案 B

---

## 三、需要桥接的 API 与数据（按现有代码归纳）

以下均来自对 `lib/` 的阅读，**不改变现有类名与实现**，仅列出需在「桥接层」暴露或序列化的内容。

### 3.1 指令型（鸿蒙 → Dart，通过 MethodChannel）

| 能力来源 | 方法/行为 | 鸿蒙侧调用名建议 | 参数（与 Dart 对应） |
|----------|------------|------------------|----------------------|
| TgoRTC | 初始化 | `init` | `Options` → Map：`{ mirror: bool, debug: bool }` |
| TgoRoomManager | 加入房间 | `joinRoom` | `RoomInfo` → Map（见 3.3）+ `micEnabled`、`cameraEnabled`、`scrennShareEnabled` |
| TgoRoomManager | 离开房间 | `leaveRoom` | 无 |
| TgoParticipant（本地） | 静音/取消静音 | `setMicrophoneEnabled` | `bool` |
| TgoParticipant（本地） | 开/关摄像头 | `setCameraEnabled` | `bool` |
| TgoAudioManager | 扬声器开关 | `setSpeakerphoneOn` | `bool` |
| TgoAudioManager | 扬声器切换 | `toggleSpeakerphone` | 无 |
| TgoParticipantManager | 邀请成员 | `invite` | `roomName: string`、`uids: string[]` |
| TgoParticipantManager | 未接听/超时 | `missed` | `roomName: string`、`uids: string[]` |

### 3.2 查询型（鸿蒙 → Dart，通过 MethodChannel，同步返回或 async 返回）

| 能力来源 | 方法/行为 | 鸿蒙侧调用名建议 | 返回（建议序列化为 Map/JSON） |
|----------|------------|------------------|-------------------------------|
| TgoRoomManager | 当前连接状态 | `getConnectStatus` | 最后一次状态：`{ roomName, status, reason }`，其中 status 用枚举整型（connecting=0/connected=1/disconnected=2） |
| TgoRoomManager | 当前房间信息 | `getCurrentRoomInfo` | RoomInfo → Map（见 3.3） |
| TgoParticipantManager | 本地参与者 | `getLocalParticipant` | 见 3.3 的 Participant 摘要 |
| TgoParticipantManager | 所有参与者 | `getAllParticipants` | `List<Participant 摘要>` |
| TgoAudioManager | 是否扬声器 | `isSpeakerOn` | bool |
| TgoParticipant（本地） | 麦克风/摄像头状态 | `getMicrophoneEnabled` / `getCameraEnabled` | bool |

### 3.3 事件/回调型（Dart → 鸿蒙，通过 EventChannel 或 MethodChannel 的 setMethodCallHandler 反调）

| Dart 侧事件源 | 事件含义 | 建议事件名/流 | 建议 payload（Map） |
|---------------|-----------|----------------|---------------------|
| TgoRoomManager.addConnectListener | 连接状态变化 | `connectStatus` | `{ roomName, status, reason }` |
| TgoParticipantManager.addNewParticipantListener | 新参与者 | `participantJoined` | Participant 摘要 |
| TgoParticipant（addLeaveListener 等） | 参与者离开 | `participantLeft` | `{ uid }` |
| 本地参与者 microphone/camera listener | 麦克风/摄像头状态变化 | `localMediaStatus` | `{ micEnabled, cameraEnabled }` |
| TgoRoomManager 的 VideoInfoListener（若鸿蒙要展示码率等） | 本地视频统计 | `localVideoInfo` | `{ width, height, bitrate, frameRate, ... }` |

上述「Participant 摘要」需在桥接层从 `TgoParticipant` 转成可序列化结构，例如：`{ uid, isLocal, micEnabled, cameraEnabled, ... }`，不暴露 Dart 对象引用。

### 3.4 需与鸿蒙约定的实体结构（Map/JSON）

- **RoomInfo**：`roomName`, `token`, `url`, `loginUID`, `creatorUID`, `maxParticipants`, `rtcType`（如 0=audio/1=video）, `isP2P`, `uidList`, `timeout`。
- **Options**：`mirror`, `debug`。
- **ConnectStatus**：建议鸿蒙与 Dart 统一用整型（例如 0=connecting, 1=connected, 2=disconnected），Dart 侧在桥接层做 enum ↔ int 转换。
- **Participant 摘要**：`uid`, `isLocal`, `micEnabled`, `cameraEnabled`（及业务需要的是否静音、是否有视频等），由桥接层在 Dart 侧从 `TgoParticipant` 读出来再组 Map。

---

## 四、实现步骤（按阶段、不写具体代码）

### 阶段一：在 Flutter 侧增加「桥接层」而不改 tgortc/manager 实现

1. **新建桥接入口与 Channel 常量**  
   - 在工程内（例如 `lib/bridge/` 或 `example/lib/bridge/`）新建纯 Dart 的「TgoRTC 鸿蒙桥接」模块。  
   - 定义 MethodChannel、EventChannel 的 channel 名称（如 `com.xxx.tgortc/bridge`），与后续鸿蒙侧完全一致。

2. **实现 MethodChannel Handler（Dart 侧）**  
   - 在桥接模块中设置 `MethodChannel.setMethodCallHandler`，根据 `call.method` 分发到：
     - `init` → 使用 `call.arguments` 中的 Map 构造 `Options`，调用 `TgoRTC.instance.init(...)`。
     - `joinRoom` → 使用参数 Map 构造 `RoomInfo`，再调 `TgoRTC.instance.roomManager.joinRoom(roomInfo, ...)`。
     - `leaveRoom` → `TgoRTC.instance.roomManager.leaveRoom()`。
     - `setMicrophoneEnabled` / `setCameraEnabled` → 取本地参与者后调 `setMicrophoneEnabled` / `setCameraEnabled`。
     - `setSpeakerphoneOn` / `toggleSpeakerphone` → `TgoRTC.instance.audioManager.*`。
     - `invite` / `missed` → `TgoRTC.instance.participantManager.invite(...)` / `missed(...)`。
     - `getConnectStatus` / `getCurrentRoomInfo` / `getLocalParticipant` / `getAllParticipants` / `isSpeakerOn` 等 → 从现有 manager/participant 读取，转成 Map 后 `result.success(...)`。
   - 所有对 `RoomInfo`、`Options`、枚举的读写都在桥接层做「Map ↔ 实体」转换，**不修改** `lib/entity/*.dart` 与 `lib/manager/*.dart` 的内部实现。

3. **实现 EventChannel 或「事件回推」**  
   - 在桥接层对 `TgoRTC.instance.roomManager`、`participantManager`、本地 participant 的 listener 做**转发**：接到 Dart 的 listener 回调后，把状态/参与者摘要等编码为 Map，通过 EventChannel 的 `Stream` 或 ArkTS 侧提供的「Dart 调原生」的逆向 Channel 推给鸿蒙。  
   - 若鸿蒙版 Flutter 的 EventChannel API 与通用 Flutter 一致，优先用 EventChannel；否则可用「ArkTS 先 invoke 一个 `registerEventSink`，Dart 侧在内存中保存 sink，再在 listener 里往该 sink 写事件」。

4. **在 Flutter 入口注册桥接**  
   - 在 example 的 `main.dart`（或鸿蒙专用入口）中，在 `runApp` 之前调用桥接模块的 `register()`，使其执行 `MethodChannel.setMethodCallHandler` 与 EventChannel 的登记。  
   - 若采用「形态 A」：鸿蒙仍通过 `FlutterPage` 打开一个只做通话+视频的 Flutter 页，该页的 `main()`/路由初始化时执行上述 `register()`。  
   - 若采用「形态 B」：需要在无 UI 的 Dart 入口里同样执行 `register()`，并保证 FlutterEngine 已启动并执行到该入口。

### 阶段二：在鸿蒙侧实现 Channel 与 UI 占位

5. **在鸿蒙工程中增加 TgoRTC 桥接 Plugin（ArkTS）**  
   - 参考 [HarmonyOS Flutter Practice: 06 — Use ArkTs to Develop Flutter Harmony Plugins](https://dev.to/shaohusuo/harmonyos-flutter-practice-06-use-arkts-to-develop-flutter-harmony-plugins-1fg8) 与项目内 `GeneratedPluginRegistrant.ets` 的写法，新增一个「TgoRTC Bridge Plugin」类，实现 `FlutterPlugin` 与 `MethodCallHandler`（以及若支持的话，EventChannel 的 StreamHandler）。  
   - 该类在 `onAttachedToEngine` 时创建与 Dart 同名的 `MethodChannel`（及 `EventChannel`），并把 `setMethodCallHandler` 指向自己。

6. **实现 ArkTS 侧 Method 分发**  
   - 在 `onMethodCall` 中根据 `call.method` 调用：
     - 对应的 TgoRTC 相关「原生能力」：若某能力必须由 Dart 实现，则**不在 ArkTS 实现该方法**，而是由鸿蒙通过该 MethodChannel **调用 Dart**（即鸿蒙发 method，Dart 做具体逻辑并 result.success）。  
   - 本方案下，**所有 TgoRTC 逻辑都在 Dart**，因此 ArkTS 的 `onMethodCall` 主要负责：**把鸿蒙 UI 的点击/操作转成 method 发给 Dart，并等待 Dart 的 result**。若鸿蒙版支持「由 Dart 主动调原生」的 API，则 ArkTS 还需实现「被 Dart 调用的接口」用于接收事件（否则用 EventChannel）。

7. **EventChannel 或逆向调用**  
   - 若使用 EventChannel：ArkTS 侧监听 EventChannel 的 stream，收到 Map 后更新 ArkTS 的 UI 状态（连接状态、参与者列表、本地静音/摄像头等）。  
   - 若使用「Dart 调原生」：在 ArkTS 的 Plugin 里提供类似 `registerEventSink` 的 method，Dart 调用后把 sink 存下来，后续 Dart 的 listener 通过该 sink 把事件推到鸿蒙。

8. **原生通话页占位（形态 A）**  
   - 新建一个「原生通话页」ArkTS 页面，其中：
     - 顶部/底部/列表等用 ArkTS 布局；  
     - 「视频区域」保留为一块 `FlutterPage`（或等价的 Flutter 视图组件），传入固定或动态的 `viewId`，该 Flutter 页内只加载「TgoRTC 逻辑 + TgoTrackRenderer」的 mini 版。  
   - 该原生页通过 bridge 调用 `joinRoom`、`leaveRoom`、`setMicrophoneEnabled` 等，并通过 EventChannel/逆向调用刷新连接状态、参与者人数、静音/摄像头图标等。

### 阶段三：视频与产品化

9. **视频窗与路由（形态 A）**  
   - 在 Flutter 侧为「仅通话+视频」的页面单独做一个 route（如 `/call`），鸿蒙打开 Flutter 时指定该 route，或通过 `FlutterPage` 的入口 query 指定。  
   - 确保该页内只包含：`TgoTrackRenderer` 的布局、以及从 EventChannel 接收的「参与者列表」用于渲染多个 `TgoTrackRenderer`（若沿用现有 call_page 的网格逻辑，可先做单路/两路）。  
   - 若希望「多路视频中的某几路」由鸿蒙控件占位（例如仅主画面 Flutter、其余为原生占位），可在后续迭代中再拆 MethodChannel 的「获取某 uid 的 viewId/textureId」等（依赖 flutter_webrtc 是否提供）。

10. **实体与兼容性**  
    - 在桥接层为 `RoomInfo`、`Options`、`ConnectStatus`、参与者摘要等维护「Dart ↔ Map」的转换函数，并写在文档或注释中，方便鸿蒙与 Flutter 共用同一份协议。  
    - 若后续鸿蒙侧改为路线 2（原生渲染），只需保留「信令/状态」相关的 MethodChannel/EventChannel，视频相关事件可再扩展（例如推送「某 uid 的流已就绪」供鸿蒙自绘）。

11. **插件注册与依赖**  
    - 在 `GeneratedPluginRegistrant.ets`（或鸿蒙工程的插件注册入口）中，把「TgoRTC Bridge Plugin」注册进去，确保 `configureFlutterEngine` 时能执行到其 `onAttachedToEngine`。  
    - 若桥接以「example 内独立 module」形式存在，需在 example 的 `ohos` 工程中把该 module 加入依赖，并保证在 Flutter 引擎创建后、首个 Flutter 页使用前完成 Channel 的绑定。

### 阶段四：文档与后续规划

12. **桥接 API 文档**  
    - 在 `docs/` 下维护《TgoRTC 鸿蒙桥接 API 说明》，列出：MethodChannel 的 method 名、入参/出参的 Map 结构、EventChannel 事件名与 payload、以及 RoomInfo/Options/ConnectStatus/Participant 摘要的字段说明。  
    - 注明当前采用的「形态 A / B」与「视频路线 1/2/3」，便于后续切换或扩展。

13. **若未来要做「形态 B + 全鸿蒙 UI」**  
    - 在文档中单独一节描述：如何把 Flutter 入口改为「无 UI」、仅执行 bridge 的 `register()` 与 TgoRTC 逻辑；  
    - 并说明视频需采用路线 2 或 3，以及对应的鸿蒙侧渲染或纹理对接工作。

---

## 五、参考文档与资源

### 5.1 Flutter × 鸿蒙集成

- 华为开发者博客（鸿蒙 × Flutter）：<https://developer.huawei.com/consumer/cn/blog/topic/03191269062405177>
- OHOS 平台适配 Flutter 三方库指导：<https://gitee.com/openharmony-sig/flutter_samples/blob/master/ohos/docs/07_plugin/ohos%E5%B9%B3%E5%8F%B0%E9%80%82%E9%85%8Dflutter%E4%B8%89%E6%96%B9%E5%BA%93%E6%8C%87%E5%AF%BC.md>
- HarmonyOS Flutter Practice: 06 — Use ArkTs to Develop Flutter Harmony Plugins：<https://dev.to/shaohusuo/harmonyos-flutter-practice-06-use-arkts-to-develop-flutter-harmony-plugins-1fg8>
- Flutter OHOS 外接纹理适配简介：<https://gitcode.com/openharmony-tpc/flutter_samples/blob/master/ohos/docs/04_development/Flutter%20OHOS%E5%A4%96%E6%8E%A5%E7%BA%B9%E7%90%86%E9%80%82%E9%85%8D%E7%AE%80%E4%BB%8B.md>
- 项目内《ohos_adaptation_steps.md》：环境、依赖、插件与运行配置的步骤。

### 5.2 鸿蒙 NEXT 原生音视频开发

- **XComponent 与 NAPI 开发指南**：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/napi-xcomponent-guidelines>
- **NdkXComponent 示例（YUV 渲染、OpenGL）**：<https://gitee.com/harmonyos_samples/ndk-xcomponent>
- **NdkOpenGL 示例（XComponent + OpenGL）**：<https://gitee.com/harmonyos_samples/ndk-opengl>
- **Audio Kit 音频开发**：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/audio-kit-intro>
- **画中画 NDK 接口**：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/pipwindow-native>

### 5.3 鸿蒙 NEXT 原生 RTC SDK

- **声网 RTC**：<https://doc.shengwang.cn/doc/rtc/harmonyos/overview/release-notes>
- **火山引擎 RTC**：<https://www.volcengine.com/docs/6348/1433812>
- **百家云 BRTC**：<https://docs.baijiayun.com/rtc/release/HarmonyOS.html>

### 5.4 鸿蒙版 Flutter 音视频库

- **fluttertpc_livekit_client**：<https://gitcode.com/openharmony-sig/fluttertpc_livekit_client>
- **fluttertpc_flutter_webrtc**：<https://gitcode.com/openharmony-sig/fluttertpc_flutter_webrtc>
- **ohos_webrtc（原生 WebRTC）**：<https://gitee.com/openharmony-sig/ohos_webrtc>

---

## 六、步骤清单速览

| 步骤 | 内容 | 阶段 |
|------|------|------|
| 1 | Flutter 侧新建桥接模块，定义 MethodChannel/EventChannel 名称 | 一 |
| 2 | Dart 侧实现 MethodChannel.setMethodCallHandler，映射到 TgoRTC/Manager 的 init、join、leave、静音、摄像头、扬声器、invite/missed 及各类 get | 一 |
| 3 | Dart 侧把 room/participant 的 listener 转成事件，通过 EventChannel 或逆向 Channel 推给鸿蒙 | 一 |
| 4 | 在 Flutter 入口（或通话页入口）中 register 桥接 | 一 |
| 5 | 鸿蒙侧新增 TgoRTC Bridge Plugin，绑定同名 MethodChannel/EventChannel | 二 |
| 6 | ArkTS 侧在 onMethodCall 中转发 UI 操作到 Dart（或直接由鸿蒙调用 Dart 的 channel）并处理 result | 二 |
| 7 | ArkTS 侧接收 EventChannel/逆向调用，更新连接状态、参与者列表、本地媒体状态等 | 二 |
| 8 | 新建「原生通话页」：ArkTS UI + 一块 FlutterPage 用作视频窗（形态 A） | 二 |
| 9 | Flutter 侧为「仅通话+视频」提供独立 route，并与鸿蒙的 FlutterPage 对应 | 三 |
| 10 | 桥接层统一 RoomInfo/Options/状态/参与者的 Map 协议，并在文档中写出 | 三 |
| 11 | 在 GeneratedPluginRegistrant 或等价处注册 TgoRTC Bridge Plugin | 三 |
| 12 | 撰写《TgoRTC 鸿蒙桥接 API 说明》并注明形态与视频路线 | 四 |

以上步骤均不要求修改 `lib/tgortc.dart`、`lib/manager/*.dart`、`lib/participant/tgo_participant.dart`、`lib/track/tgo_track_renderer.dart` 的既有逻辑，仅在「桥接层」做转发与序列化。
