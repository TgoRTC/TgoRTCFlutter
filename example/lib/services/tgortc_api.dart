import 'dart:convert';
import 'package:http/http.dart' as http;

/// API 响应类型
class RoomResponse {
  final String sourceChannelId;
  final int sourceChannelType;
  final String roomId;
  final String creator;
  final String token;
  final String url;
  final int status;
  final String createdAt;
  final int maxParticipants;
  final int timeout;
  final int rtcType;
  final List<String> uids;

  RoomResponse({
    required this.sourceChannelId,
    required this.sourceChannelType,
    required this.roomId,
    required this.creator,
    required this.token,
    required this.url,
    required this.status,
    required this.createdAt,
    required this.maxParticipants,
    required this.timeout,
    required this.rtcType,
    required this.uids,
  });

  factory RoomResponse.fromJson(Map<String, dynamic> json) {
    return RoomResponse(
      sourceChannelId: json['source_channel_id'] ?? '',
      sourceChannelType: json['source_channel_type'] ?? 0,
      roomId: json['room_id'] ?? '',
      creator: json['creator'] ?? '',
      token: json['token'] ?? '',
      url: json['url'] ?? '',
      status: json['status'] ?? 0,
      createdAt: json['created_at'] ?? '',
      maxParticipants: json['max_participants'] ?? 2,
      timeout: json['timeout'] ?? 30,
      rtcType: json['rtc_type'] ?? 1,
      uids: List<String>.from(json['uids'] ?? []),
    );
  }
}

/// TgoRTC API 服务
class TgoRTCApi {
  final String baseUrl;

  TgoRTCApi(this.baseUrl);

  String _getApiBase() {
    String url = baseUrl.trim();
    // 移除末尾的斜杠
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // 只有在没有协议前缀时才添加 http://
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url;
  }

  /// 创建房间
  Future<RoomResponse> createRoom({
    required String roomId,
    required String uid,
    int maxParticipants = 9,
    int rtcType = 1, // 1 = video, 0 = audio
  }) async {
    final apiBase = _getApiBase();
    final response = await http.post(
      Uri.parse('$apiBase/api/v1/rooms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'source_channel_id': 'channel_flutter',
        'source_channel_type': 0,
        'creator': uid,
        'room_id': roomId,
        'rtc_type': rtcType,
        'invite_on': 0,
        'max_participants': maxParticipants,
        'uids': [_generateUID()],
        'device_type': 'app',
      }),
    );

    if (response.statusCode == 200) {
      return RoomResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? '创建房间失败');
    }
  }

  /// 加入房间
  Future<RoomResponse> joinRoom({
    required String roomId,
    required String uid,
  }) async {
    final apiBase = _getApiBase();
    final response = await http.post(
      Uri.parse('$apiBase/api/v1/rooms/$roomId/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': uid,
       'device_type': 'app'
      }),
    );

    if (response.statusCode == 200) {
      return RoomResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? '加入房间失败');
    }
  }

  /// 离开房间
  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  }) async {
    final apiBase = _getApiBase();
    try {
      await http.post(
        Uri.parse('$apiBase/api/v1/rooms/$roomId/leave'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
        }),
      );
    } catch (e) {
      // 忽略离开房间的错误
      print('离开房间 API 调用失败: $e');
    }
  }

  /// 生成 UUID
  static String _generateUID() {
    const chars = '0123456789abcdef';
    final buffer = StringBuffer();
    for (int i = 0; i < 32; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) {
        buffer.write('-');
      }
      final index = (DateTime.now().microsecondsSinceEpoch + i * 17) % 16;
      buffer.write(chars[index]);
    }
    return buffer.toString();
  }

  /// 生成用户 ID
  static String generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch % 100000}';
  }
}
