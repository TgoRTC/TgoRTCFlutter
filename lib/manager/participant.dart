import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

import '../participant/tgo_participant.dart';
import '../utils/logger.dart';

class ParticipantManager {
  ParticipantManager._internal();
  static final ParticipantManager _instance = ParticipantManager._internal();
  static ParticipantManager get instance => _instance;
  final List<Function(TgoParticipant)> _newParticipantListeners = [];
  TgoParticipant? _localParticipant;
  final Map<String, TgoParticipant> _remoteParticipants = {};

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
  }

  List<TgoParticipant> getAllParticipants() {
    final local = getLocalParticipant();
    final remote = getRemoteParticipants();
    // 去重：排除与本地相同 uid 的远程参与者
    final filtered = remote.where((p) => p.uid != local.uid).toList();
    return [local, ...filtered];
  }

  List<TgoParticipant> getRemoteParticipants() {
    var participants =
        TgoRTC.instance.roomManager.room?.remoteParticipants ?? {};
    var roomInfo = TgoRTC.instance.roomManager.currentRoomInfo;
    var uidList = roomInfo?.uidList ?? [];

    // 两个都为空，返回空数组
    if (participants.isEmpty && uidList.isEmpty) {
      return [];
    }

    List<TgoParticipant> list = [];
    Set<String> addedUids = {};

    // 先遍历 uidList
    for (var uid in uidList) {
      RemoteParticipant? matchedParticipant;
      for (var p in participants.values) {
        if (p.identity == uid) {
          matchedParticipant = p;
          break;
        }
      }
      // 使用缓存或创建新的
      var tgoParticipant = _remoteParticipants[uid] ??=
          TgoParticipant(uid, null, matchedParticipant);
      list.add(tgoParticipant);
      addedUids.add(uid);
    }

    // 再添加 participants 中不在 uidList 的
    for (var p in participants.values) {
      if (!addedUids.contains(p.identity)) {
        var tgoParticipant = _remoteParticipants[p.identity] ??=
            TgoParticipant(p.identity, null, p);
        list.add(tgoParticipant);
      }
    }

    return list;
  }

  inviteParticipant(List<String> uids) {
    var roomInfo = TgoRTC.instance.roomManager.currentRoomInfo;
    if (roomInfo == null) {
      return;
    }

    // 获取已存在的 uid 列表
    var existingUids = _remoteParticipants.keys.toSet();

    // 过滤掉已存在的 uid
    var newUids = uids.where((uid) => !existingUids.contains(uid)).toList();

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
      newUids = newUids.sublist(0, availableSlots);
    }
    for (var uid in newUids) {
      var tgoParticipant = TgoParticipant(uid, null, null);
      _remoteParticipants[uid] = tgoParticipant;
      _setNewParticipant(tgoParticipant);
    }
    roomInfo.uidList.addAll(newUids);
  }

  setParticipantJoin(RemoteParticipant participant) {
    var tgoParticipant = _remoteParticipants[participant.identity];
    if (tgoParticipant != null) {
      tgoParticipant.setRemoteParticipant(participant);
      return;
    }

    // new participant
    tgoParticipant = TgoParticipant(participant.identity, null, participant);
    _remoteParticipants[participant.identity] = tgoParticipant;
    _setNewParticipant(tgoParticipant);
  }

  setParticipantLeave(RemoteParticipant participant) {
    var tgoParticipant = _remoteParticipants[participant.identity];
    if (tgoParticipant != null) {
      tgoParticipant.notifyLeave();
    }
    // remove
    _remoteParticipants.remove(participant.identity);
    TgoRTC.instance.roomManager.currentRoomInfo?.uidList
        .remove(participant.identity);
  }

  _setNewParticipant(TgoParticipant participant) {
    for (var element in _newParticipantListeners) {
      element(participant);
    }
  }

  addNewParticipantListener(Function(TgoParticipant) listener) {
    _newParticipantListeners.add(listener);
  }

  removeNewParticipantListener(Function(TgoParticipant) listener) {
    _newParticipantListeners.remove(listener);
  }
}
