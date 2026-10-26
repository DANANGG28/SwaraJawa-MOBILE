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

class WeekStreakDay {
  const WeekStreakDay({
    required this.label,
    this.aktif = false,
    this.isToday = false,
    this.isFuture = false,
  });

  final String label;
  final bool aktif;
  final bool isToday;
  final bool isFuture;

  factory WeekStreakDay.fromJson(Map<String, dynamic> json) {
    return WeekStreakDay(
      label: (json['label'] ?? '').toString(),
      aktif: json['aktif'] == true || json['aktif'] == 1,
      isToday: json['is_today'] == true || json['is_today'] == 1,
      isFuture: json['is_future'] == true || json['is_future'] == 1,
    );
  }

  /// Helper untuk membuat kalender mingguan fallback jika data dari backend belum ada
  static List<WeekStreakDay> generateFallback({
    int currentStreak = 0,
    String? lastActivityDate,
  }) {
    final now = DateTime.now();
    // Cari hari Senin minggu ini (ISO 8601: weekday 1 = Senin)
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    const labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    DateTime? lastDate;
    if (lastActivityDate != null && lastActivityDate.isNotEmpty) {
      final parsed = DateTime.tryParse(lastActivityDate);
      if (parsed != null) {
        lastDate = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    final todayOnly = DateTime(now.year, now.month, now.day);
    final isTodayActive = lastDate != null && lastDate.isAtSameMomentAs(todayOnly);

    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final isToday = day.isAtSameMomentAs(todayOnly);
      final isFuture = day.isAfter(todayOnly);

      bool aktif = false;
      if (!isFuture && currentStreak > 0) {
        if (isToday) {
          aktif = isTodayActive;
        } else {
          final diffDays = todayOnly.difference(day).inDays;
          final maxBack = isTodayActive ? currentStreak - 1 : currentStreak;
          aktif = diffDays <= maxBack && diffDays >= 0;
        }
      }

      return WeekStreakDay(
        label: labels[i],
        aktif: aktif,
        isToday: isToday,
        isFuture: isFuture,
      );
    });
  }
}

class ProgresData {
  const ProgresData({
    required this.ringkasan,
    required this.levels,
    this.weekStreak = const [],
  });

  final ProgresRingkasan ringkasan;
  final List<ProgresLevel> levels;
  final List<WeekStreakDay> weekStreak;

  factory ProgresData.fromJson(Map<String, dynamic> json) {
    final ringkasan = json['ringkasan'] is Map
        ? Map<String, dynamic>.from(json['ringkasan'] as Map)
        : <String, dynamic>{};
    final rawLevels = (json['progres'] ?? json['levels'] ?? json['data']) as List?;
    final rawWeekStreak = (json['week_streak'] ?? json['weekStreak']) as List?;

    return ProgresData(
      ringkasan: ProgresRingkasan.fromJson(ringkasan),
      levels: rawLevels
              ?.whereType<Map>()
              .map((e) => ProgresLevel.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      weekStreak: rawWeekStreak
              ?.whereType<Map>()
              .map((e) => WeekStreakDay.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}
