import 'bagian.dart';
import 'json_utils.dart';

/// Unit materi (level_materi) — berada di bawah satu Topik dan memuat
/// beberapa Bagian (pembahasan).
class LevelMateri {
  const LevelMateri({
    required this.id,
    required this.namaMateri,
    this.topikId,
    this.deskripsi,
    this.rewardExp = 0,
    this.urutan = 0,
    this.urutanUnit = 0,
    this.jumlahSoal = 0,
    this.lulusCount = 0,
    this.persen = 0,
    this.status = 'terkunci',
    this.tanggalSelesai,
    this.pembahasan = const [],
  });

  final int id;
  final int? topikId;
  final String namaMateri;
  final String? deskripsi;
  final int rewardExp;
  final int urutan;

  /// Nomor unit relatif di dalam topiknya (1, 2, 3, ...).
  final int urutanUnit;

  final int jumlahSoal;
  final int lulusCount;
  final int persen;
  final String status;
  final String? tanggalSelesai;
  final List<Bagian> pembahasan;

  static const statusTerkunci = 'terkunci';
  static const statusBerjalan = 'berjalan';
  static const statusSelesai = 'selesai';

  bool get terkunci => status == statusTerkunci;
  bool get selesai => status == statusSelesai;
  bool get berjalan => status == statusBerjalan;
  bool get adaBagian => pembahasan.isNotEmpty;

  factory LevelMateri.fromJson(Map<String, dynamic> json) {
    final rawPembahasan = json['pembahasan'];
    return LevelMateri(
      id: asInt(json['id']),
      topikId: json['topik_id'] == null ? null : asInt(json['topik_id']),
      namaMateri: (json['nama_materi'] ?? '').toString(),
      deskripsi: json['deskripsi']?.toString(),
      rewardExp: asInt(json['reward_exp']),
      urutan: asInt(json['urutan']),
      urutanUnit: asInt(json['urutan_unit']),
      jumlahSoal: asInt(json['jumlah_soal']),
      lulusCount: asInt(json['lulus_count']),
      persen: asInt(json['persen']),
      status: (json['status'] ?? 'terkunci').toString(),
      tanggalSelesai: json['tanggal_selesai']?.toString(),
      pembahasan: rawPembahasan is List
          ? rawPembahasan
              .whereType<Map>()
              .map((e) => Bagian.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
