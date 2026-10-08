import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/quiz_result.dart';

class KuisService {
  KuisService(this._client);

  final ApiClient _client;

  Future<JawabanResult> jawab({
    required int soalId,
    required dynamic jawaban,
  }) async {
    if (kDebugMode) debugPrint('[KUIS] jawab soal=$soalId jawaban=$jawaban');
    final data = await _client.postJson('/kuis/jawab', data: {
      'soal_id': soalId,
      'jawaban': jawaban,
    });
    return JawabanResult.fromJson(data);
  }

  Future<Map<String, dynamic>> selesai(int levelMateriId) async {
    return _client.postJson('/kuis/selesai', data: {
      'level_materi_id': levelMateriId,
    });
  }
}
