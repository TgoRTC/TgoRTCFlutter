# tgortcflutter

[![pub package](https://img.shields.io/pub/v/tgortcflutter.svg)](https://pub.dev/packages/tgortcflutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Flutter SDK for audio and video calling based on [LiveKit](https://livekit.io/). Provides easy-to-use APIs for room management, participant tracking, and media control.

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

### Release Steps

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Commit and merge the changes into `main`
4. Create and push a version tag

Example:

```bash
./scripts/release.sh 1.0.2
```

This script will:

- verify `pubspec.yaml` version matches `1.0.2`
- switch to `main`
- pull the latest changes
- create tag `v1.0.2`
- push the tag to GitHub

After the tag is pushed, `.github/workflows/publish.yml` will publish the package automatically.

### Workflows

- `.github/workflows/ci.yml`
  - runs `flutter pub get`
  - runs `flutter analyze`
  - runs `dart pub publish --dry-run`

- `.github/workflows/publish.yml`
  - runs on `v*` tags
  - verifies tag version matches `pubspec.yaml`
  - runs `dart pub publish --force`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
