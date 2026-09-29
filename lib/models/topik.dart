import 'json_utils.dart';
import 'level_materi.dart';

/// Topik — tingkat teratas kurikulum (dapat berisi banyak unit).
class Topik {
  const Topik({
    required this.id,
    required this.nama,
    this.deskripsi,
    this.urutan = 0,
    this.totalUnit = 0,
    this.unitSelesai = 0,
    this.totalSoal = 0,
    this.lulusCount = 0,
    this.persen = 0,
    this.status = 'anyar',
  });

  final int id;
  final String nama;
  final String? deskripsi;
  final int urutan;
  final int totalUnit;
  final int unitSelesai;
  final int totalSoal;
  final int lulusCount;
  final int persen;
  final String status;

  bool get selesai => status == 'selesai';
  bool get berjalan => status == 'berjalan';
  bool get anyar => status == 'anyar';

  factory Topik.fromJson(Map<String, dynamic> json) {
    return Topik(
      id: asInt(json['id']),
      nama: (json['nama'] ?? '').toString(),
      deskripsi: json['deskripsi']?.toString(),
      urutan: asInt(json['urutan']),
      totalUnit: asInt(json['total_unit']),
      unitSelesai: asInt(json['unit_selesai']),
      totalSoal: asInt(json['total_soal']),
      lulusCount: asInt(json['lulus_count']),
      persen: asInt(json['persen']),
      status: (json['status'] ?? 'anyar').toString(),
    );
  }
}

/// Satu topik beserta daftar unit (yang di dalamnya memuat bagian).
class TopikDetail {
  const TopikDetail({required this.topik, required this.units});

  final Topik topik;
  final List<LevelMateri> units;

  factory TopikDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final rawTopik = data['topik'] is Map
        ? Map<String, dynamic>.from(data['topik'] as Map)
        : <String, dynamic>{};
    final rawUnits = (data['units'] is List) ? data['units'] as List : const [];
    return TopikDetail(
      topik: Topik.fromJson(rawTopik),
      units: rawUnits
          .whereType<Map>()
          .map((e) => LevelMateri.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
