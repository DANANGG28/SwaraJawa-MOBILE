import '../core/network/api_client.dart';
import '../models/chat.dart';

class ChatService {
  ChatService(this._client);

  final ApiClient _client;

  Future<ChatAskResult> tanya({
    required String pertanyaan,
    int? sessionId,
  }) async {
    final data = await _client.postJson('/chat', data: {
      'pertanyaan': pertanyaan,
      'session_id': sessionId,
    });
    return ChatAskResult.fromJson(data);
  }

  Future<List<ChatSessionInfo>> histori() async {
    final raw = await _client.dio.get('/chat/histori');
    final data = raw.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ChatSessionInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<List<ChatMessageItem>> detailSesi(int sessionId) async {
    final data = await _client.getJson('/chat/sesi/$sessionId');
    final session = Map<String, dynamic>.from(data['session'] ?? data);
    final raw = (session['messages'] ?? []) as List;
    return raw
        .whereType<Map>()
        .map((e) => ChatMessageItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> hapusSesi(int sessionId) async {
    await _client.deleteJson('/chat/sesi/$sessionId');
  }
}
