import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../models/quiz_result.dart';
import '../config/app_config.dart';

/// Pemutaran audio TTS terpusat.
///
/// Strategi:
/// 1. Putar dari URL yang sudah dinormalisasi ([AppConfig.resolveUrl]).
/// 2. Bila URL kosong/gagal, fallback ke `audio_base64` (khusus `/speech/tts`).
///
/// Semua kegagalan dicatat ke log (terlihat di `adb logcat` saat debug)
/// sehingga penyebab "tidak bunyi" mudah didiagnosis.
class TtsPlayback {
  const TtsPlayback._();

  /// Putar audio hasil `/speech/tts`. Mengembalikan `true` bila berhasil.
  static Future<bool> playTts(AudioPlayer player, TtsResult result) async {
    final url = AppConfig.resolveUrl(result.audioUrl);
    if (url.isNotEmpty) {
      try {
        await player.stop();
        await player.play(UrlSource(url));
        return true;
      } catch (e, s) {
        debugPrint('[TTS] gagal memutar URL "$url": $e');
        debugPrintStack(stackTrace: s);
      }
    } else {
      debugPrint('[TTS] audio_url kosong dari server.');
    }

    final bytes = _decode(result.audioBase64);
    if (bytes != null && bytes.isNotEmpty) {
      try {
        await player.stop();
        await player.play(BytesSource(bytes, mimeType: result.mime));
        debugPrint('[TTS] berhasil memutar fallback audio_base64.');
        return true;
      } catch (e, s) {
        debugPrint('[TTS] gagal memutar fallback base64: $e');
        debugPrintStack(stackTrace: s);
      }
    }
    return false;
  }

  /// Putar audio dari URL saja (mis. umpan balik kuis suara tanpa base64).
  static Future<bool> playUrl(AudioPlayer player, String? audioUrl) async {
    final url = AppConfig.resolveUrl(audioUrl);
    if (url.isEmpty) {
      debugPrint('[TTS] URL audio kosong dari server.');
      return false;
    }
    try {
      await player.stop();
      await player.play(UrlSource(url));
      return true;
    } catch (e, s) {
      debugPrint('[TTS] gagal memutar URL "$url": $e');
      debugPrintStack(stackTrace: s);
      return false;
    }
  }

  static Uint8List? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final normalized = raw.replaceFirst(RegExp(r'^data:[^;]+;base64,'), '');
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }
}
