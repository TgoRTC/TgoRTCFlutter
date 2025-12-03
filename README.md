# tgortcflutter

基于 LiveKit 的 Flutter 音视频通话 SDK。

## 架构设计

### 参与者加入/离开事件流程

```
┌─────────────────────────────────────────────────────────┐
│                    RoomManager                          │
│  (监听 LiveKit RoomEvent)                                │
├─────────────────────────────────────────────────────────┤
│  RoomConnectedEvent           → 本地加入                  │
│  RoomDisconnectedEvent        → 本地离开                  │
│  ParticipantConnectedEvent    → 远程加入                  │
│  ParticipantDisconnectedEvent → 远程离开                  │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                  ParticipantManager                     │
├─────────────────────────────────────────────────────────┤
│  setParticipantJoin()  → 创建/更新 TgoParticipant        │
│  setParticipantLeave() → 通知离开并清理                   │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                   TgoParticipant                        │
├─────────────────────────────────────────────────────────┤
│  notifyJoined()  → 通知 _joinedListeners                 │
│  notifyLeave()   → 通知 _leaveListeners → dispose()     │
│  (监听 ParticipantEvent: 麦克风/摄像头/说话状态)           │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                      业务层                              │
│  participant.addJoinedListener(() => ...)               │
│  participant.addLeaveListener(() => ...)                │
└─────────────────────────────────────────────────────────┘
```

### 设计说明

由于 LiveKit SDK 的限制：
- `ParticipantDisconnectedEvent` 是 **RoomEvent**，不是 ParticipantEvent
- 参与者断开时，participant 对象已失效，无法从内部监听

因此采用 **RoomManager 监听 → ParticipantManager 分发 → TgoParticipant 通知** 的设计模式。

## 核心模块

| 模块 | 说明 |
|-----|------|
| `RoomManager` | 房间管理，连接/断开，监听房间事件 |
| `ParticipantManager` | 参与者管理，缓存本地/远程参与者 |
| `TgoParticipant` | 参与者封装，提供状态监听 |
| `TgoTrackRenderer` | 视频轨道渲染 |
| `TgoAudioManager` | 音频管理，扬声器切换 |

## 使用示例

```dart
// 加入房间
await TgoRTC.instance.roomManager.joinRoom(roomInfo);

// 获取本地参与者
var local = TgoRTC.instance.participantManager.getLocalParticipant();

// 监听加入/离开
local.addJoinedListener(() => print('已加入房间'));
local.addLeaveListener(() => print('已离开房间'));

// 监听麦克风/摄像头状态
local.addMicrophoneListener((enabled) => print('麦克风: $enabled'));
local.addCameraListener((enabled) => print('摄像头: $enabled'));

// 切换摄像头/麦克风
await local.setCameraEnabled(true);
await local.setMicrophoneEnabled(true);

// 离开房间
TgoRTC.instance.roomManager.leaveRoom();
```
