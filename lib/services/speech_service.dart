import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/audio_bytes_stub.dart'
    if (dart.library.io) '../core/network/audio_bytes_io.dart'
    if (dart.library.html) '../core/network/audio_bytes_web.dart' as audio_bytes;
import '../models/quiz_result.dart';

class SpeechService {
  SpeechService(this._client);

  final ApiClient _client;

  /// Web merekam dalam container WebM/Opus, mobile dalam M4A/AAC.
  String get _recordFilename => kIsWeb ? 'rekaman.webm' : 'rekaman.m4a';

  /// Content-Type multipart yang sesuai agar diterima Laravel `mimes` dan
  /// ElevenLabs (webm/opus untuk web, m4a/AAC untuk Android/iOS).
  DioMediaType get _recordContentType =>
      kIsWeb ? DioMediaType('audio', 'webm') : DioMediaType('audio', 'mp4');

  Future<TtsResult> tts(String teks, {String? voice}) async {
    final data = await _client.postJson('/speech/tts', data: {
      'teks': teks,
      if (voice != null) 'voice': voice,
    });
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
      'audio': demo
          ? 'demo'
          : MultipartFile.fromBytes(
              await audio_bytes.readAudioBytes(audioPath),
              filename: _recordFilename,
              contentType: _recordContentType,
            ),
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
      'audio': demo
          ? 'demo'
          : MultipartFile.fromBytes(
              await audio_bytes.readAudioBytes(audioPath),
              filename: _recordFilename,
              contentType: _recordContentType,
            ),
      if (mockTranscript != null) 'mock_transcript': mockTranscript,
    });
    final data = await _client.postMultipart('/soal/$soalId/latihan-ngomong', formData: form);
    return LatihanNgomongResult.fromJson(data);
  }

  Future<String> audioBase64FromPath(String path) => audio_bytes.audioBase64(path);
}
