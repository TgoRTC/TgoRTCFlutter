import 'package:livekit_client/livekit_client.dart';
import 'package:tgortcflutter/tgortc.dart';

import '../entity/tgo_local_participant.dart';
import '../entity/tgo_remote_participant.dart';
import '../utils/logger.dart';

class ParticipantManager {
  ParticipantManager._internal();
  static final ParticipantManager _instance = ParticipantManager._internal();
  static ParticipantManager get instance => _instance;
  final List<Function(TgoRemoteParticipant)> _newParticipantListeners = [];

  TgoLocalParticipant? getLocalParticipant() {
    if (TgoRTC.instance.roomManager.room == null) {
      return null;
    }
    var participant = TgoRTC.instance.roomManager.room!.localParticipant;
    if (participant == null) {
      return null;
    }
    return TgoLocalParticipant(participant);
  }

  List<TgoRemoteParticipant> getRemoteParticipants() {
    var participants =
        TgoRTC.instance.roomManager.room?.remoteParticipants ?? {};
    var roomInfo = TgoRTC.instance.roomManager.currentRoomInfo;
    var uidList = roomInfo?.uidList ?? [];

    // 两个都为空，返回空数组
    if (participants.isEmpty && uidList.isEmpty) {
      return [];
    }

    List<TgoRemoteParticipant> list = [];
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
      list.add(TgoRemoteParticipant(uid, matchedParticipant));
      addedUids.add(uid);
    }

    // 再添加 participants 中不在 uidList 的
    for (var p in participants.values) {
      if (!addedUids.contains(p.identity)) {
        list.add(TgoRemoteParticipant(p.identity, p));
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
    var existingUids = getRemoteParticipants().map((p) => p.uid).toSet();

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
      _setNewParticipant(TgoRemoteParticipant(uid, null));
    }
    roomInfo.uidList.addAll(newUids);
  }

  setParticipantJoin(RemoteParticipant participant) {
    List<TgoRemoteParticipant> list = getRemoteParticipants();
    for (var element in list) {
      if (element.uid == participant.identity) {
        element.setParticipant(participant);
        return;
      }
    }

    // new participant
    var tgoParticipant =
        TgoRemoteParticipant(participant.identity, participant);
    _setNewParticipant(tgoParticipant);
    list.add(tgoParticipant);
  }

  setParticipantLeave(RemoteParticipant participant) {
    List<TgoRemoteParticipant> list = getRemoteParticipants();
    for (var element in list) {
      if (element.uid == participant.identity) {
        element.setLeave();
        return;
      }
    }
  }

  _setNewParticipant(TgoRemoteParticipant participant) {
    for (var element in _newParticipantListeners) {
      element(participant);
    }
  }

  addNewParticipantListener(Function(TgoRemoteParticipant) listener) {
    _newParticipantListeners.add(listener);
  }

  removeNewParticipantListener(Function(TgoRemoteParticipant) listener) {
    _newParticipantListeners.remove(listener);
  }
}
