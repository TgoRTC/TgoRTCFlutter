import 'package:flutter/material.dart';
import 'package:tgortcflutter/tgortc.dart';
import 'package:tgortcflutter/entity/room_info.dart';
import 'package:tgortcflutter/entity/const.dart';
import 'package:tgortcflutter/participant/tgo_participant.dart';
import 'package:tgortcflutter/track/tgo_track_renderer.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../services/tgortc_api.dart';

class CallPage extends StatefulWidget {
  final String serverUrl;
  final RoomResponse roomResponse;
  final String uid;

  const CallPage({
    super.key,
    required this.serverUrl,
    required this.roomResponse,
    required this.uid,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> with TickerProviderStateMixin {
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _isConnected = false;
  bool _isConnecting = true;
  String _statusMessage = '正在连接...';
  List<TgoParticipant> _participants = [];
  TgoParticipant? _localParticipant;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _joinRoom();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _leaveRoom();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    // 添加连接状态监听
    TgoRTC.instance.roomManager.addConnectListener(_onConnectStatusChanged);

    // 添加新参与者监听
    TgoRTC.instance.participantManager.addNewParticipantListener(_onNewParticipant);

    // 使用 API 返回的数据创建房间信息
    final roomInfo = RoomInfo(
      widget.roomResponse.roomId,
      widget.roomResponse.token,
      widget.roomResponse.url,
      widget.uid,
      widget.roomResponse.creator,
    );
    roomInfo.rtcType = widget.roomResponse.rtcType == 1 ? RTCType.video : RTCType.audio;
    roomInfo.maxParticipants = widget.roomResponse.maxParticipants;
    roomInfo.timeout = widget.roomResponse.timeout;
    roomInfo.uidList = widget.roomResponse.uids;

    try {
      // 加入房间
      await TgoRTC.instance.roomManager.joinRoom(
        roomInfo,
        micEnabled: true,
        cameraEnabled: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _statusMessage = '连接失败: $e';
        });
      }
    }
  }

  void _onConnectStatusChanged(String roomName, ConnectStatus status, String reason) {
    if (!mounted) return;

    setState(() {
      switch (status) {
        case ConnectStatus.connected:
          _isConnected = true;
          _isConnecting = false;
          _statusMessage = '已连接';
          _localParticipant = TgoRTC.instance.participantManager.getLocalParticipant();
          _updateParticipants();
          _setupLocalParticipantListeners();
          break;
        case ConnectStatus.connecting:
          _isConnecting = true;
          _statusMessage = '正在连接...';
          break;
        case ConnectStatus.disconnected:
          _isConnected = false;
          _isConnecting = false;
          _statusMessage = '已断开连接';
          break;
      }
    });
  }

  void _setupLocalParticipantListeners() {
    _localParticipant?.addMicrophoneStatusListener(_onMicrophoneChanged);
    _localParticipant?.addCameraStatusListener(_onCameraChanged);
  }

  void _onMicrophoneChanged(bool enabled) {
    if (mounted) {
      setState(() => _isMicEnabled = enabled);
    }
  }

  void _onCameraChanged(bool enabled) {
    if (mounted) {
      setState(() => _isCameraEnabled = enabled);
    }
  }

  void _onNewParticipant(TgoParticipant participant) {
    participant.addJoinedListener(() => _updateParticipants());
    participant.addLeaveListener(() => _updateParticipants());
    participant.addCameraStatusListener((_) => _updateParticipants());
    _updateParticipants();
  }

  void _updateParticipants() {
    if (!mounted) return;
    setState(() {
      _participants = TgoRTC.instance.participantManager.getAllParticipants();
    });
  }

  Future<void> _leaveRoom() async {
    TgoRTC.instance.roomManager.removeConnectListener(_onConnectStatusChanged);
    _localParticipant?.removeMicrophoneStatusListener(_onMicrophoneChanged);
    _localParticipant?.removeCameraStatusListener(_onCameraChanged);
    
    // 调用 API 通知服务器离开房间
    try {
      final api = TgoRTCApi(widget.serverUrl);
      await api.leaveRoom(
        roomId: widget.roomResponse.roomId,
        uid: widget.uid,
      );
    } catch (e) {
      // 忽略错误
    }
    
    await TgoRTC.instance.roomManager.leaveRoom();
  }

  Future<void> _toggleMicrophone() async {
    await _localParticipant?.setMicrophoneEnabled(!_isMicEnabled);
  }

  Future<void> _toggleCamera() async {
    await _localParticipant?.setCameraEnabled(!_isCameraEnabled);
  }

  Future<void> _hangUp() async {
    await _leaveRoom();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: Stack(
        children: [
          // 背景
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Color(0xFF1A1A3E),
                  Color(0xFF0F0F23),
                ],
              ),
            ),
          ),

          // 主内容
          SafeArea(
            child: Column(
              children: [
                // 顶部状态栏
                _buildHeader(),

                // 参与者网格
                Expanded(
                  child: _isConnecting
                      ? _buildConnectingView()
                      : _isConnected
                          ? _buildParticipantsGrid()
                          : _buildErrorView(),
                ),

                // 底部控制栏
                if (_isConnected) _buildControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected
                        ? const Color(0xFF10B981)
                        : _isConnecting
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.roomResponse.roomId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            '${_participants.length} 人',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.3 + _pulseController.value * 0.3),
                      const Color(0xFF8B5CF6).withOpacity(0.3 + _pulseController.value * 0.3),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.wifi_calling_3_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEF4444).withOpacity(0.2),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '返回',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsGrid() {
    if (_participants.isEmpty) {
      return const Center(
        child: Text(
          '等待其他参与者加入...',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      );
    }

    final count = _participants.length;
    final crossAxisCount = count <= 1 ? 1 : count <= 4 ? 2 : 3;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: count == 1 ? 3 / 4 : 1,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          return _buildParticipantTile(_participants[index]);
        },
      ),
    );
  }

  Widget _buildParticipantTile(TgoParticipant participant) {
    final isLocal = participant.isLocal;
    final renderer = TgoTrackRenderer(
      source: TrackSource.camera,
      fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
    renderer.setParticipant(participant);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: isLocal
              ? const Color(0xFF6366F1).withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 视频渲染
            participant.getCameraEnabled()
                ? renderer.build()
                : Container(
                    color: const Color(0xFF1A1A3E),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isLocal
                                ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                                : [const Color(0xFF10B981), const Color(0xFF059669)],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            participant.uid.isNotEmpty
                                ? participant.uid[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

            // 遮罩层
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isLocal ? '我' : _formatUid(participant.uid),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!participant.getMicrophoneEnabled())
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.mic_off_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 本地标识
            if (isLocal)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '本地',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatUid(String uid) {
    if (uid.length > 10) {
      return '${uid.substring(0, 10)}...';
    }
    return uid;
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 麦克风按钮
          _buildControlButton(
            icon: _isMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: _isMicEnabled ? '静音' : '取消静音',
            isActive: _isMicEnabled,
            onTap: _toggleMicrophone,
          ),

          // 摄像头按钮
          _buildControlButton(
            icon: _isCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            label: _isCameraEnabled ? '关闭摄像头' : '打开摄像头',
            isActive: _isCameraEnabled,
            onTap: _toggleCamera,
          ),

          // 挂断按钮
          _buildControlButton(
            icon: Icons.call_end_rounded,
            label: '挂断',
            isActive: false,
            isDestructive: true,
            onTap: _hangUp,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final backgroundColor = isDestructive
        ? const Color(0xFFEF4444)
        : isActive
            ? Colors.white.withOpacity(0.15)
            : Colors.white.withOpacity(0.1);

    final iconColor = isDestructive
        ? Colors.white
        : isActive
            ? Colors.white
            : Colors.white.withOpacity(0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              border: Border.all(
                color: isDestructive
                    ? Colors.transparent
                    : isActive
                        ? const Color(0xFF6366F1).withOpacity(0.5)
                        : Colors.white.withOpacity(0.1),
                width: 2,
              ),
              boxShadow: isDestructive
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
