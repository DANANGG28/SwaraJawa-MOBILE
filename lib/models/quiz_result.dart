import 'json_utils.dart';

/// Hasil penilaian satu butir soal dari POST /kuis/jawab.
class JawabanResult {
  const JawabanResult({
    required this.benar,
    required this.skor,
    this.skorTertinggi = 0,
    this.detail = const {},
    this.kunciJawaban,
    this.expDidapat = 0,
    this.rewardExp = 0,
    this.levelSelesai = false,
    this.levelBerikutnya,
    this.totalExp = 0,
    this.currentStreak = 0,
    this.highestStreak = 0,
  });

  final bool benar;
  final int skor;
  final int skorTertinggi;
  final Map<String, dynamic> detail;
  final dynamic kunciJawaban;
  final int expDidapat;
  final int rewardExp;
  final bool levelSelesai;
  final String? levelBerikutnya;
  final int totalExp;
  final int currentStreak;
  final int highestStreak;

  /// Teks kunci untuk ditampilkan pada popup feedback.
  String get kunciDisplay {
    final kunci = detail['kunci'];
    if (kunci is String && kunci.isNotEmpty) return kunci;
    if (kunci is List) return kunci.join(' ');
    if (detail['kunci_teks'] != null) return detail['kunci_teks'].toString();
    if (kunciJawaban is Map) {
      final k = kunciJawaban as Map;
      final v = k['teks'] ?? k['jawaban'] ?? k['urutan'] ?? k['susunan'];
      if (v is List) return v.join(' ');
      if (v != null) return v.toString();
    }
    return '';
  }

  factory JawabanResult.fromJson(Map<String, dynamic> json) {
    return JawabanResult(
      benar: json['benar'] == true,
      skor: asInt(json['skor']),
      skorTertinggi: asInt(json['skor_tertinggi']),
      detail: json['detail'] is Map
          ? Map<String, dynamic>.from(json['detail'] as Map)
          : <String, dynamic>{},
      kunciJawaban: json['kunci_jawaban'],
      expDidapat: asInt(json['exp_didapat']),
      rewardExp: asInt(json['reward_exp']),
      levelSelesai: json['level_selesai'] == true,
      levelBerikutnya: json['level_berikutnya']?.toString(),
      totalExp: asInt(json['total_exp']),
      currentStreak: asInt(json['current_streak']),
      highestStreak: asInt(json['highest_streak']),
    );
  }
}

class KuisSuaraResult {
  const KuisSuaraResult({
    required this.transkripsi,
    required this.skor,
    required this.kategori,
    required this.benar,
    this.mock = false,
    this.teksRespons,
    this.audioUrl,
    this.skorTertinggi = 0,
    this.expDidapat = 0,
    this.rewardExp = 0,
    this.levelSelesai = false,
    this.levelBerikutnya,
    this.totalExp = 0,
    this.currentStreak = 0,
  });

  final String transkripsi;
  final int skor;
  final String kategori;
  final bool benar;
  final bool mock;
  final String? teksRespons;
  final String? audioUrl;
  final int skorTertinggi;
  final int expDidapat;
  final int rewardExp;
  final bool levelSelesai;
  final String? levelBerikutnya;
  final int totalExp;
  final int currentStreak;

  factory KuisSuaraResult.fromJson(Map<String, dynamic> json) {
    return KuisSuaraResult(
      transkripsi: (json['transkripsi'] ?? '').toString(),
      skor: asInt(json['skor']),
      kategori: (json['kategori'] ?? '').toString(),
      benar: json['benar'] == true,
      mock: json['mock'] == true,
      teksRespons: json['teks_respons']?.toString(),
      audioUrl: json['audio_url']?.toString(),
      skorTertinggi: asInt(json['skor_tertinggi']),
      expDidapat: asInt(json['exp_didapat']),
      rewardExp: asInt(json['reward_exp']),
      levelSelesai: json['level_selesai'] == true,
      levelBerikutnya: json['level_berikutnya']?.toString(),
      totalExp: asInt(json['total_exp']),
      currentStreak: asInt(json['current_streak']),
    );
  }
}

class LatihanNgomongResult {
  const LatihanNgomongResult({
    required this.transkripsi,
    this.feedbackText,
    this.audioUrl,
    this.mock = false,
  });

  final String transkripsi;
  final String? feedbackText;
  final String? audioUrl;
  final bool mock;

  factory LatihanNgomongResult.fromJson(Map<String, dynamic> json) {
    return LatihanNgomongResult(
      transkripsi: (json['transkripsi'] ?? '').toString(),
      feedbackText: json['feedback_text']?.toString(),
      audioUrl: json['audio_url']?.toString(),
      mock: json['mock'] == true,
    );
  }
}

class TtsResult {
  const TtsResult({this.audioUrl, this.durasiDetik, this.mock = false});

  final String? audioUrl;
  final double? durasiDetik;
  final bool mock;

  factory TtsResult.fromJson(Map<String, dynamic> json) {
    return TtsResult(
      audioUrl: json['audio_url']?.toString(),
      durasiDetik: json['durasi_detik'] == null ? null : asDouble(json['durasi_detik']),
      mock: json['mock'] == true,
    );
  }
}
