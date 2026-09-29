import 'json_utils.dart';

class ChatSessionInfo {
  const ChatSessionInfo({
    required this.id,
    required this.judul,
    this.updatedAt,
  });

  final int id;
  final String judul;
  final String? updatedAt;

  factory ChatSessionInfo.fromJson(Map<String, dynamic> json) {
    return ChatSessionInfo(
      id: asInt(json['id']),
      judul: (json['judul'] ?? 'Obrolan anyar').toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class ChatMessageItem {
  const ChatMessageItem({
    required this.role,
    required this.pesan,
    this.sumber = const [],
    this.waktu,
  });

  final String role;
  final String pesan;
  final List<String> sumber;
  final String? waktu;

  bool get isUser => role == 'user';

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    final rawSumber = json['sumber'];
    List<String> sumber = const [];
    if (rawSumber is List) {
      sumber = rawSumber.map((e) => e.toString()).toList();
    }
    return ChatMessageItem(
      role: (json['role'] ?? 'assistant').toString(),
      pesan: (json['pesan'] ?? json['jawaban'] ?? json['message'] ?? '').toString(),
      sumber: sumber,
      waktu: json['waktu']?.toString(),
    );
  }
}

class ChatAskResult {
  const ChatAskResult({
    required this.jawaban,
    required this.sumber,
    this.sessionId,
    this.sessionTitle,
  });

  final String jawaban;
  final List<String> sumber;
  final int? sessionId;
  final String? sessionTitle;

  factory ChatAskResult.fromJson(Map<String, dynamic> json) {
    final map = (json['jawaban'] == null && json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final rawSumber = map['sumber'];
    List<String> sumber = const [];
    if (rawSumber is List) {
      sumber = rawSumber.map((e) => e.toString()).toList();
    }
    return ChatAskResult(
      jawaban: (map['jawaban'] ?? map['pesan'] ?? '').toString(),
      sumber: sumber,
      sessionId: map['session_id'] == null ? null : asInt(map['session_id']),
      sessionTitle: map['session_title']?.toString(),
    );
  }
}
