import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../models/quiz_result.dart';

class SpeechService {
  SpeechService(this._client);

  final ApiClient _client;

  Future<TtsResult> tts(String teks) async {
    final data = await _client.postJson('/speech/tts', data: {'teks': teks});
    return TtsResult.fromJson(data);
  }

  Future<String> stt(String audioBase64, {String? mockTranscript}) async {
    final data = await _client.postJson('/speech/stt', data: {
      'audio': audioBase64,
      if (mockTranscript != null) 'mock_transcript': mockTranscript,
    });
    return (data['transcript'] ?? data['text'] ?? '').toString();
  }

  Future<Map<String, dynamic>> sts({
    required String audioBase64,
    required String teksReferensi,
    String? mockTranscript,
  }) async {
    return _client.postJson('/speech/sts', data: {
      'audio': audioBase64,
      'teks_referensi': teksReferensi,
      if (mockTranscript != null) 'mock_transcript': mockTranscript,
    });
  }

  Future<KuisSuaraResult> quizSuara(
    int soalId, {
    required String audioPath,
    String? mockTranscript,
    bool demo = false,
  }) async {
    final form = FormData.fromMap({
      'audio': demo ? 'demo' : await MultipartFile.fromFile(audioPath, filename: 'rekaman.m4a'),
      if (mockTranscript != null) 'mock_transcript': mockTranscript,
    });
    final data = await _client.postMultipart('/soal/$soalId/quiz-suara', formData: form);
    return KuisSuaraResult.fromJson(data);
  }

  Future<LatihanNgomongResult> latihanNgomong(
    int soalId, {
    required String audioPath,
    String? mockTranscript,
    bool demo = false,
  }) async {
    final form = FormData.fromMap({
      'audio': demo ? 'demo' : await MultipartFile.fromFile(audioPath, filename: 'rekaman.m4a'),
      if (mockTranscript != null) 'mock_transcript': mockTranscript,
    });
    final data = await _client.postMultipart('/soal/$soalId/latihan-ngomong', formData: form);
    return LatihanNgomongResult.fromJson(data);
  }

  Future<String> audioBase64FromPath(String path) async {
    final bytes = await File(path).readAsBytes();
    return base64Encode(bytes);
  }
}
