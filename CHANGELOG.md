# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-01-27

### Added

- `TgoParticipantManager.getPendingParticipantCreatedAt()` - 获取未加入参与者的创建时间，用于超时检查
- `TgoParticipantManager.removeParticipantByUid(String uid)` - 按 uid 移除未加入的参与者，会先触发 leave 通知再移除
- `TgoParticipantManager.missed(String roomName, List<String> uids)` - 处理超时未接听，批量移除参与者
- `TgoParticipant.setRemoteParticipant(RemoteParticipant?)` - 更新关联的远端参与者实例

### Changed

- 参与者超时逻辑重构：超时未加入的参与者改为直接移除并触发 leave 通知，不再使用 `isTimeout` 标记
- `TgoParticipantManager.invite(roomName, uids)` 替代原 `inviteParticipant(uids)`，增加 `roomName` 校验
- `getRemoteParticipants()`、`getAllParticipants()` 移除 `includeTimeout` 参数

### Removed

- `TgoParticipant` 的 `createdAt`、`isTimeout`、`setTimeout()` 及超时相关监听 API（超时改由 Manager 直接移除参与者）

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
