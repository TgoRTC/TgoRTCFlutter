# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-09

### Added

- Initial release
- `TgoRTC` - Main SDK entry point with singleton pattern
- `TgoRoomManager` - Room connection and disconnection management
- `TgoParticipantManager` - Local and remote participant management
- `TgoParticipant` - Participant wrapper with state listeners
  - Microphone state listener
  - Camera state listener
  - Speaking state listener
  - Join/Leave event listeners
- `TgoTrackRenderer` - Video track rendering widget
- `TgoAudioManager` - Audio output management (speaker/earpiece switching)
- Support for LiveKit as the underlying WebRTC infrastructure
