# tgortcflutter

[![pub package](https://img.shields.io/pub/v/tgortcflutter.svg)](https://pub.dev/packages/tgortcflutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Flutter SDK for audio and video calling based on [LiveKit](https://livekit.io/). Provides easy-to-use APIs for room management, participant tracking, and media control.

## 中文说明

`tgortcflutter` 是一个基于 [LiveKit](https://livekit.io/) 封装的 Flutter 音视频通话 SDK，主要用于快速集成单聊、多人通话、房间管理、参与者管理以及音视频控制能力。

### 功能特性

- 支持音频通话和视频通话
- 支持本地与远端参与者管理
- 支持麦克风、摄像头开关控制
- 支持扬声器 / 听筒切换
- 支持实时事件监听
- 支持快速接入 LiveKit 服务端

### 安装方式

在项目的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  tgortcflutter: ^<latest-version>
```

或者直接执行：

```bash
flutter pub add tgortcflutter
```

然后执行：

```bash
flutter pub get
```

### 平台权限配置

#### iOS

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for audio calls</string>
```

#### Android

在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### 快速开始

初始化 SDK：

```dart
import 'package:tgortcflutter/tgortc.dart';

TgoRTC.instance.init(Options());
```

加入房间：

```dart
final roomInfo = RoomInfo(
  'room-name',
  'your-access-token',
  'wss://your-livekit-server.com',
  'your-user-id',
  'creator-user-id',
);

await TgoRTC.instance.roomManager.joinRoom(roomInfo);
```

获取参与者：

```dart
final local = TgoRTC.instance.participantManager.getLocalParticipant();
final remotes = TgoRTC.instance.participantManager.getRemoteParticipants();
```

控制音视频：

```dart
await local.setCameraEnabled(true);
await local.setMicrophoneEnabled(true);
await local.switchCamera();
await TgoRTC.instance.audioManager.setSpeakerphoneOn(true);
```

渲染视频：

```dart
final renderer = TgoTrackRenderer();
renderer.setParticipant(participant);
return renderer.build();
```

离开房间：

```dart
await TgoRTC.instance.roomManager.leaveRoom();
```

### 发布说明

当前仓库已经接入 GitHub Actions 自动发布到 pub.dev。

发布前请确认：

- 当前工作区干净，没有未提交改动
- `pub.dev` 后台已经开启 GitHub Actions Automated Publishing
- 仓库配置为 `TgoRTC/TgoRTCFlutter`
- Tag 规则配置为 `v{{version}}`

执行发布命令：

```bash
bash ./scripts/release.sh
```

脚本会自动完成这些操作：

- 自动递增 `pubspec.yaml` 的 patch 版本号
- 自动补充对应版本的 `CHANGELOG.md`
- 切换到 `main` 并拉取最新代码
- 自动提交版本变更
- 自动推送到 `origin/main`
- 自动创建并推送 `v<version>` 标签
- 自动触发 GitHub Actions 发布到 pub.dev

如果要指定版本号发布：

```bash
bash ./scripts/release.sh 1.0.2
```

如果需要查看更详细的调试日志：

```bash
RELEASE_DEBUG=1 bash ./scripts/release.sh
```

## Features

- 🎥 Video/Audio calling support
- 👥 Participant management (local & remote)
- 🎤 Microphone/Camera control
- 🔊 Speaker/Earpiece switching
- 📡 Real-time event listeners
- 🔄 Easy integration with LiveKit backend

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  tgortcflutter: ^<latest-version>
```

> 💡 Replace `<latest-version>` with the version shown in the badge above, or run:
> ```bash
> flutter pub add tgortcflutter
> ```

Then run:

```bash
flutter pub get
```

## Platform Setup

Since this package is based on LiveKit and WebRTC, you need to configure platform-specific permissions:

### iOS

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for audio calls</string>
```

### Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

## Quick Start

### Initialize SDK

```dart
import 'package:tgortcflutter/tgortc.dart';

// Initialize with options
TgoRTC.instance.init(Options());
```

### Join a Room

```dart
final roomInfo = RoomInfo(
  'room-name',
  'your-access-token',
  'wss://your-livekit-server.com',
  'your-user-id',
  'creator-user-id',
);

await TgoRTC.instance.roomManager.joinRoom(roomInfo);
```

### Get Participants

```dart
// Get local participant
final local = TgoRTC.instance.participantManager.getLocalParticipant();

// Get remote participants
final remotes = TgoRTC.instance.participantManager.getRemoteParticipants();
```

### Listen to Events

```dart
// Join/Leave events
local.addJoinedListener(() => print('Joined room'));
local.addLeaveListener(() => print('Left room'));

// Media state changes
local.addMicrophoneStatusListener((enabled) => print('Microphone: $enabled'));
local.addCameraStatusListener((enabled) => print('Camera: $enabled'));
local.addSpeakingListener((speaking) => print('Speaking: $speaking'));
```

### Control Media

```dart
// Toggle camera/microphone
await local.setCameraEnabled(true);
await local.setMicrophoneEnabled(true);

// Switch camera
await local.switchCamera();

// Switch audio output
await TgoRTC.instance.audioManager.setSpeakerphoneOn(true);
```

### Render Video

```dart
final renderer = TgoTrackRenderer();
renderer.setParticipant(participant);

// In your widget tree
return renderer.build();
```

### Leave Room

```dart
await TgoRTC.instance.roomManager.leaveRoom();
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    RoomManager                          │
│  (Listens to LiveKit RoomEvent)                         │
├─────────────────────────────────────────────────────────┤
│  RoomConnectedEvent           → Local join              │
│  RoomDisconnectedEvent        → Local leave             │
│  ParticipantConnectedEvent    → Remote join             │
│  ParticipantDisconnectedEvent → Remote leave            │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                  ParticipantManager                     │
├─────────────────────────────────────────────────────────┤
│  setParticipantJoin()  → Create/Update TgoParticipant   │
│  setParticipantLeave() → Notify leave and cleanup       │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                   TgoParticipant                        │
├─────────────────────────────────────────────────────────┤
│  notifyJoined()  → Notify _joinedListeners              │
│  notifyLeave()   → Notify _leaveListeners → dispose()   │
│  (Listens to ParticipantEvent: mic/camera/speaking)     │
└─────────────────────────────────────────────────────────┘
```

## Core Modules

| Module | Description |
|--------|-------------|
| `TgoRTC` | Main SDK entry point (singleton) |
| `TgoRoomManager` | Room connection and event handling |
| `TgoParticipantManager` | Local/remote participant management |
| `TgoParticipant` | Participant wrapper with state listeners |
| `TgoTrackRenderer` | Video track rendering widget |
| `TgoAudioManager` | Audio output management |

## Example

Check the [example](example/) directory for a complete working example.

## Release

This repository supports automated publishing to pub.dev with GitHub Actions.

### One-time Setup

Enable automated publishing for `tgortcflutter` in pub.dev:

1. Open the package admin page: `https://pub.dev/packages/tgortcflutter/admin`
2. Enable `GitHub Actions` automated publishing
3. Set repository to `TgoRTC/TgoRTCFlutter`
4. Set tag pattern to `v{{version}}`

### Branch Policy

- CI runs on every push to `main`
- Publishing is only triggered by pushing a version tag
- The tag must point to a commit already merged into `main`
- pub.dev automated publishing must be enabled in the package admin page before the workflow can publish successfully

### Release Steps

1. Make sure your working tree is clean
2. Run the release script from the repository root

Example:

```bash
bash ./scripts/release.sh
```

This script will:

- verify the working tree is clean
- auto-increment the patch version in `pubspec.yaml`
- create a matching `CHANGELOG.md` entry if the target version is missing
- switch to `main`
- pull the latest changes
- commit the version bump to `main`
- push the commit to `main`
- create a matching version tag such as `v1.0.2`
- push the tag to GitHub
- print the GitHub Actions and pub.dev links for the release

If you want to release a specific version manually, you can still pass it:

```bash
bash ./scripts/release.sh 1.0.2
```

If you want shell-level trace logs while debugging the release flow:

```bash
RELEASE_DEBUG=1 bash ./scripts/release.sh
```

After the tag is pushed, `.github/workflows/publish.yml` will publish the package automatically.

### Notes

- If a version tag such as `v1.0.4` already exists, the script will stop instead of reusing it.
- If a release fails after the tag has already been pushed, the next normal run will publish the next patch version.
- pub.dev validates `CHANGELOG.md`, so every published version must appear there.

### Workflows

- `.github/workflows/ci.yml`
  - runs `flutter pub get`
  - runs `flutter analyze --no-fatal-infos`
  - runs `dart pub publish --dry-run`

- `.github/workflows/publish.yml`
  - runs on `v*` tags
  - uses Dart's official GitHub Actions publishing workflow
  - publishes to pub.dev using GitHub Actions OIDC credentials

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
