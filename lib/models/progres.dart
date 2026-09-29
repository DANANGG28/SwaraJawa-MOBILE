import 'json_utils.dart';

class ProgresRingkasan {
  const ProgresRingkasan({
    this.totalExp = 0,
    this.currentStreak = 0,
    this.highestStreak = 0,
    this.levelSelesai = 0,
    this.totalLevel = 0,
    this.persentase = 0,
  });

  final int totalExp;
  final int currentStreak;
  final int highestStreak;
  final int levelSelesai;
  final int totalLevel;
  final int persentase;

  factory ProgresRingkasan.fromJson(Map<String, dynamic> json) {
    return ProgresRingkasan(
      totalExp: asInt(json['total_exp']),
      currentStreak: asInt(json['current_streak']),
      highestStreak: asInt(json['highest_streak']),
      levelSelesai: asInt(json['level_selesai']),
      totalLevel: asInt(json['total_level']),
      persentase: asInt(json['persentase']),
    );
  }
}

class ProgresLevel {
  const ProgresLevel({
    required this.levelMateriId,
    required this.namaMateri,
    this.urutan = 0,
    this.status = 'terkunci',
    this.tanggalSelesai,
  });

  final int levelMateriId;
  final String namaMateri;
  final int urutan;
  final String status;
  final String? tanggalSelesai;

  factory ProgresLevel.fromJson(Map<String, dynamic> json) {
    return ProgresLevel(
      levelMateriId: asInt(json['level_materi_id'] ?? json['id']),
      namaMateri: (json['nama_materi'] ?? '').toString(),
      urutan: asInt(json['urutan']),
      status: (json['status'] ?? 'terkunci').toString(),
      tanggalSelesai: json['tanggal_selesai']?.toString(),
    );
  }
}

class ProgresData {
  const ProgresData({required this.ringkasan, required this.levels});

  final ProgresRingkasan ringkasan;
  final List<ProgresLevel> levels;

  factory ProgresData.fromJson(Map<String, dynamic> json) {
    final ringkasan = json['ringkasan'] is Map
        ? Map<String, dynamic>.from(json['ringkasan'] as Map)
        : <String, dynamic>{};
    final rawLevels = (json['progres'] ?? json['levels'] ?? json['data']) as List?;
    return ProgresData(
      ringkasan: ProgresRingkasan.fromJson(ringkasan),
      levels: rawLevels
              ?.whereType<Map>()
              .map((e) => ProgresLevel.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}
