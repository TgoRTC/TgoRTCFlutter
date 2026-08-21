import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

import '../utils/logger.dart';

/// Manager for handling local and remote participants in a room.
///
/// This is a singleton class that tracks all participants in the current room.
///
/// ## Usage
///
/// ```dart
/// // Get local participant
/// final local = TgoRTC.instance.participantManager.getLocalParticipant();
///
/// // Get all remote participants
/// final remotes = TgoRTC.instance.participantManager.getRemoteParticipants();
///
/// // Listen for new participants
/// TgoRTC.instance.participantManager.addNewParticipantListener((participant) {
///   print('New participant: ${participant.uid}');
/// });
/// ```
class TgoParticipantManager {
  TgoParticipantManager._internal();
  static final TgoParticipantManager _instance =
      TgoParticipantManager._internal();
  static TgoParticipantManager get instance => _instance;
  final List<Function(TgoParticipant)> _newParticipantListeners = [];
  final List<Function(TgoParticipant)> _participantJoinedListeners = [];
  TgoParticipant? _localParticipant;
  final Map<String, TgoParticipant> _remoteParticipants = {};
  final Map<String, DateTime> _participantCreatedAt = {};

  TgoParticipant getLocalParticipant() {
    if (TgoRTC.instance.roomManager.currentRoomInfo == null) {
      throw StateError('Cannot get local participant: room info is null');
    }
    var participant = TgoRTC.instance.roomManager.room?.localParticipant;
    var loginUID = TgoRTC.instance.roomManager.currentRoomInfo!.loginUID;
    if (_localParticipant == null) {
      _localParticipant = TgoParticipant(loginUID, participant, null);
    } else if (participant != null) {
      // 更新内部的 LocalParticipant（如果之前创建时是 null）
      _localParticipant!.setLocalParticipant(participant);
    }
    return _localParticipant!;
  }

  void clear() {
    _localParticipant?.dispose();
    _localParticipant = null;
    for (var p in _remoteParticipants.values) {
      p.dispose();
    }
    _remoteParticipants.clear();
    _participantCreatedAt.clear();
  }

  /// 获取所有参与者列表
  List<TgoParticipant> getAllParticipants() {
    final local = getLocalParticipant();
    final remote = getRemoteParticipants();
    // 去重：排除与本地相同 uid 的远程参与者
    final filtered = remote.where((p) => p.uid != local.uid).toList();
    return [local, ...filtered];
  }

  /// 获取远程参与者列表
  List<TgoParticipant> getRemoteParticipants() {
    var participants =
        TgoRTC.instance.roomManager.room?.remoteParticipants ?? {};
    var roomInfo = TgoRTC.instance.roomManager.currentRoomInfo;
    var uidList = roomInfo?.uidList ?? [];
    var loginUID = roomInfo?.loginUID;
    // 两个都为空，返回空数组
    if (participants.isEmpty && uidList.isEmpty) {
      return [];
    }

    List<TgoParticipant> list = [];
    Set<String> addedUids = {};

    // 先遍历 uidList
    for (var uid in uidList) {
      if (uid == loginUID) continue;
      RemoteParticipant? matchedParticipant;
      for (var p in participants.values) {
        if (p.identity == uid) {
          matchedParticipant = p;
          break;
        }
      }
      // 使用缓存或创建新的
      var tgoParticipant = _remoteParticipants[uid];
      if (tgoParticipant == null) {
        tgoParticipant = TgoParticipant(uid, null, matchedParticipant);
        _remoteParticipants[uid] = tgoParticipant;
        _participantCreatedAt[uid] = DateTime.now();
      } else if (matchedParticipant != null) {
        _bindRemoteParticipant(tgoParticipant, matchedParticipant);
      }
      list.add(tgoParticipant);
      addedUids.add(uid);
    }

    // 再添加 participants 中不在 uidList 的
    for (var p in participants.values) {
      if (!addedUids.contains(p.identity)) {
        var tgoParticipant = _remoteParticipants[p.identity];
        if (tgoParticipant == null) {
          tgoParticipant = TgoParticipant(p.identity, null, p);
          _remoteParticipants[p.identity] = tgoParticipant;
          _participantCreatedAt[p.identity] = DateTime.now();
        } else {
          _bindRemoteParticipant(tgoParticipant, p);
        }
        list.add(tgoParticipant);
      }
    }

    return list;
  }

  /// 获取未加入参与者的创建时间（uid -> createdAt），用于超时直接删除
  Map<String, DateTime> getPendingParticipantCreatedAt() {
    final m = <String, DateTime>{};
    for (var e in _remoteParticipants.entries) {
      if (!e.value.isJoined && _participantCreatedAt.containsKey(e.key)) {
        m[e.key] = _participantCreatedAt[e.key]!;
      }
    }
    return m;
  }

  /// 按 uid 直接删除参与者，会先通过 leave 事件通知 UI，再移除
  void removeParticipantByUid(String uid) {
    final tgoParticipant = _remoteParticipants[uid];
    if (tgoParticipant == null || tgoParticipant.isJoined) {
      return;
    }
    tgoParticipant.notifyLeave();
    _remoteParticipants.remove(uid);
    _participantCreatedAt.remove(uid);
    TgoRTC.instance.roomManager.currentRoomInfo?.uidList.remove(uid);
  }

  // 超时未接听
  missed(String roomName, List<String> uids) {
    var roomInfo = TgoRTC.instance.roomManager.currentRoomInfo;
    if (roomInfo == null || roomInfo.roomName != roomName) {
      return;
    }
    for (var uid in uids) {
      removeParticipantByUid(uid);
    }
  }

  // 邀请
  invite(String roomName, List<String> uids) {
    var roomInfo = TgoRTC.instance.roomManager.currentRoomInfo;
    if (roomInfo == null || roomInfo.roomName != roomName) {
      return;
    }

    // 同时按缓存、uidList、本机 UID 和本批输入去重。把新 UID 加入
    // existingUids 后再继续遍历，可以保持调用方传入顺序。
    final existingUids = <String>{
      ..._remoteParticipants.keys,
      ...roomInfo.uidList,
      roomInfo.loginUID,
    };
    final newUids = <String>[];
    for (final uid in uids) {
      if (uid.isEmpty || !existingUids.add(uid)) {
        continue;
      }
      newUids.add(uid);
    }

    if (newUids.isEmpty) {
      return;
    }

    // 计算当前数量和可添加数量
    var currentCount = roomInfo.uidList.length;
    var availableSlots = roomInfo.maxParticipants - currentCount;

    if (availableSlots <= 0) {
      Logger.error('已达到最大参与人数限制: ${roomInfo.maxParticipants}');
      return;
    }

    if (newUids.length > availableSlots) {
      Logger.error(
          '邀请人数超出限制，最多还能添加 $availableSlots 人，实际邀请 ${newUids.length} 人');
      newUids.removeRange(availableSlots, newUids.length);
    }

    // 先完整写入参与者缓存和 uidList，再发送任何通知。监听器会同步读取
    // getAllParticipants()，因此通知时 uidList 必须已经是最终状态。
    final newParticipants = <TgoParticipant>[];
    final createdAt = DateTime.now();
    for (final uid in newUids) {
      final tgoParticipant = TgoParticipant(uid, null, null);
      _remoteParticipants[uid] = tgoParticipant;
      _participantCreatedAt[uid] = createdAt;
      newParticipants.add(tgoParticipant);
    }
    roomInfo.uidList.addAll(newUids);

    for (final participant in newParticipants) {
      _setNewParticipant(participant);
    }
  }

  setParticipantJoin(RemoteParticipant participant) {
    var tgoParticipant = _remoteParticipants[participant.identity];
    if (tgoParticipant != null) {
      _bindRemoteParticipant(tgoParticipant, participant);
      return;
    }

    // new participant
    var uidList = TgoRTC.instance.roomManager.currentRoomInfo?.uidList;
    if (uidList != null && !uidList.contains(participant.identity)) {
      uidList.add(participant.identity);
    }
    tgoParticipant = TgoParticipant(participant.identity, null, participant);
    _remoteParticipants[participant.identity] = tgoParticipant;
    _setNewParticipant(tgoParticipant);
    _setParticipantJoined(tgoParticipant);
  }

  /// Binds a real LiveKit participant to an existing placeholder exactly once.
  ///
  /// A uid in [RoomInfo.uidList] may represent an invited participant that has
  /// not joined the LiveKit room yet. The transition from placeholder to a
  /// bound [RemoteParticipant] is the authoritative remote-joined event.
  void _bindRemoteParticipant(
      TgoParticipant tgoParticipant, RemoteParticipant participant) {
    final wasJoined = tgoParticipant.isJoined;
    tgoParticipant.setRemoteParticipant(participant);
    if (!wasJoined && tgoParticipant.isJoined) {
      _setParticipantJoined(tgoParticipant);
    }
  }

  setParticipantLeave(RemoteParticipant participant) {
    var tgoParticipant = _remoteParticipants[participant.identity];
    if (tgoParticipant != null) {
      tgoParticipant.notifyLeave();
    }
    _remoteParticipants.remove(participant.identity);
    _participantCreatedAt.remove(participant.identity);
    TgoRTC.instance.roomManager.currentRoomInfo?.uidList
        .remove(participant.identity);
  }

  _setNewParticipant(TgoParticipant participant) {
    for (var element in _newParticipantListeners) {
      element(participant);
    }
  }

  _setParticipantJoined(TgoParticipant participant) {
    for (var element in _participantJoinedListeners.toList()) {
      element(participant);
    }
  }

  addNewParticipantListener(Function(TgoParticipant) listener) {
    _newParticipantListeners.add(listener);
  }

  removeNewParticipantListener(Function(TgoParticipant) listener) {
    _newParticipantListeners.remove(listener);
  }

  /// Invoked when a remote participant has actually joined the LiveKit room.
  /// This is intentionally separate from [addNewParticipantListener], which
  /// also represents uidList-only placeholder participants.
  addParticipantJoinedListener(Function(TgoParticipant) listener) {
    _participantJoinedListeners.add(listener);
  }

  removeParticipantJoinedListener(Function(TgoParticipant) listener) {
    _participantJoinedListeners.remove(listener);
  }
}
