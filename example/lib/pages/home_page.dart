import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/tgortc_api.dart';
import 'call_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _serverController = TextEditingController(text: '');
  final _roomController = TextEditingController();
  bool _isLoading = false;
  
  // 自动生成用户 ID
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = TgoRTCApi.generateUserId();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  Future<void> _createRoom() async {
    await _handleRoom(isCreator: true);
  }

  Future<void> _joinRoom() async {
    await _handleRoom(isCreator: false);
  }

  // 默认服务器地址
  static const String _defaultServerUrl = 'http://47.117.96.203:8080';

  Future<void> _handleRoom({required bool isCreator}) async {
    if (_roomController.text.isEmpty) {
      _showError('请输入房间号');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _requestPermissions();

      final serverUrl = _serverController.text.trim().isEmpty 
          ? _defaultServerUrl 
          : _serverController.text.trim();
      final api = TgoRTCApi(serverUrl);
      final RoomResponse response;

      if (isCreator) {
        // 创建房间
        response = await api.createRoom(
          roomId: _roomController.text.trim(),
          uid: _uid,
          maxParticipants: 9,
          rtcType: 1, // video
        );
      } else {
        // 加入房间
        response = await api.joinRoom(
          roomId: _roomController.text.trim(),
          uid: _uid,
        );
      }

      if (!mounted) return;

      // 跳转到通话页面
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CallPage(
            serverUrl: serverUrl,
            roomResponse: response,
            uid: _uid,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F23),
              Color(0xFF1A1A3E),
              Color(0xFF0F0F23),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo 区域
                const SizedBox(height: 40),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'TgoRTC',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '实时音视频通话',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 60),

                // 输入框区域
                _buildInputField(
                  controller: _serverController,
                  label: 'TgoRTC 服务器地址',
                  hint: '默认: http://47.117.96.203:8080',
                  icon: Icons.dns_rounded,
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  controller: _roomController,
                  label: '房间号',
                  hint: '输入房间名称',
                  icon: Icons.meeting_room_rounded,
                ),
                const SizedBox(height: 40),

                // 按钮区域
                Row(
                  children: [
                    Expanded(
                      child: _buildButton(
                        label: '创建房间',
                        icon: Icons.add_circle_outline_rounded,
                        gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        onPressed: _isLoading ? null : _createRoom,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildButton(
                        label: '加入房间',
                        icon: Icons.login_rounded,
                        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                        onPressed: _isLoading ? null : _joinRoom,
                      ),
                    ),
                  ],
                ),

                if (_isLoading) ...[
                  const SizedBox(height: 32),
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                    ),
                  ),
                ],

                // 用户 ID 显示
                const SizedBox(height: 32),
                Text(
                  '用户 ID: ${_uid.substring(0, 10)}...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
          ),
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF6366F1),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: gradient),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
