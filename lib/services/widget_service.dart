import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/siswa.dart';

/// Menjembatani data progres siswa (streak, EXP, hari aktif) ke Home Screen
/// Widget native Android lewat paket `home_widget`.
///
/// Kalender memakai estimasi: hari-hari aktif diturunkan dari `current_streak`
/// (N hari terakhir s/d hari ini) dan diperkaya dengan tanggal yang benar-benar
/// tercatat sejak widget dipakai. Data disimpan di SharedPreferences milik
/// plugin (`HomeWidgetPreferences`) dan dibaca oleh provider Kotlin.
class WidgetService {
  WidgetService._();

  static const _androidCalendar =
      'com.example.sjmobile.widget.StreakCalendarWidgetProvider';
  static const _androidMini =
      'com.example.sjmobile.widget.StreakMiniWidgetProvider';

  static const _kStreak = 'streak';
  static const _kHighest = 'highest_streak';
  static const _kExp = 'total_exp';
  static const _kNama = 'nama';
  static const _kActiveDays = 'active_days';

  /// Menyimpan data siswa lalu meminta kedua widget menggambar ulang.
  static Future<void> sync(Siswa? siswa) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (siswa == null) return clear();

    try {
      final now = DateTime.now();
      final aktif = <String>{
        ...(await _bacaHariAktif()),
        _iso(now),
      };
      for (var i = 0; i < siswa.currentStreak; i++) {
        aktif.add(_iso(now.subtract(Duration(days: i))));
      }

      final daftar = aktif.toList()..sort();
      final dipangkas = daftar.length > 120
          ? daftar.sublist(daftar.length - 120)
          : daftar;

      await HomeWidget.saveWidgetData<String>(_kActiveDays, dipangkas.join(','));
      await HomeWidget.saveWidgetData<int>(_kStreak, siswa.currentStreak);
      await HomeWidget.saveWidgetData<int>(_kHighest, siswa.highestStreak);
      await HomeWidget.saveWidgetData<int>(_kExp, siswa.totalExp);
      await HomeWidget.saveWidgetData<String>(_kNama, _namaDepan(siswa.namaLengkap));
      await _gambarUlang();
    } catch (e) {
      debugPrint('WidgetService.sync gagal: $e');
    }
  }

  /// Membersihkan data widget saat logout.
  static Future<void> clear() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await HomeWidget.saveWidgetData<String>(_kActiveDays, null);
      await HomeWidget.saveWidgetData<int>(_kStreak, null);
      await HomeWidget.saveWidgetData<int>(_kHighest, null);
      await HomeWidget.saveWidgetData<int>(_kExp, null);
      await HomeWidget.saveWidgetData<String>(_kNama, null);
      await _gambarUlang();
    } catch (e) {
      debugPrint('WidgetService.clear gagal: $e');
    }
  }

  static Future<void> _gambarUlang() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: _androidCalendar);
    await HomeWidget.updateWidget(qualifiedAndroidName: _androidMini);
  }

  static Future<Set<String>> _bacaHariAktif() async {
    final raw = await HomeWidget.getWidgetData<String>(_kActiveDays) ?? '';
    return raw
        .split(',')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toSet();
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _namaDepan(String nama) {
    final trimmed = nama.trim();
    if (trimmed.isEmpty) return 'Kanca';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}
