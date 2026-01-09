# tgortcflutter

[![pub package](https://img.shields.io/pub/v/tgortcflutter.svg)](https://pub.dev/packages/tgortcflutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Flutter SDK for audio and video calling based on [LiveKit](https://livekit.io/). Provides easy-to-use APIs for room management, participant tracking, and media control.

基于 LiveKit 的 Flutter 音视频通话 SDK，提供简洁易用的房间管理、参与者追踪和媒体控制 API。

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
  url: 'wss://your-livekit-server.com',
  token: 'your-access-token',
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
local.addMicrophoneListener((enabled) => print('Microphone: $enabled'));
local.addCameraListener((enabled) => print('Camera: $enabled'));
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
TgoRTC.instance.audioManager.setSpeakerphoneEnabled(true);
```

### Render Video

```dart
TgoTrackRenderer(
  participant: participant,
  videoInfo: VideoInfo.camera,
)
```

### Leave Room

```dart
TgoRTC.instance.roomManager.leaveRoom();
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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
