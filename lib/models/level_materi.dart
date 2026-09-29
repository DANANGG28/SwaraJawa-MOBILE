import 'json_utils.dart';

class LevelMateri {
  const LevelMateri({
    required this.id,
    required this.namaMateri,
    this.deskripsi,
    this.rewardExp = 0,
    this.urutan = 0,
    this.jumlahSoal = 0,
    this.status = 'terkunci',
    this.tanggalSelesai,
  });

  final int id;
  final String namaMateri;
  final String? deskripsi;
  final int rewardExp;
  final int urutan;
  final int jumlahSoal;
  final String status;
  final String? tanggalSelesai;

  static const statusTerkunci = 'terkunci';
  static const statusBerjalan = 'berjalan';
  static const statusSelesai = 'selesai';

  bool get terkunci => status == statusTerkunci;
  bool get selesai => status == statusSelesai;
  bool get berjalan => status == statusBerjalan;

  factory LevelMateri.fromJson(Map<String, dynamic> json) {
    return LevelMateri(
      id: asInt(json['id']),
      namaMateri: (json['nama_materi'] ?? '').toString(),
      deskripsi: json['deskripsi']?.toString(),
      rewardExp: asInt(json['reward_exp']),
      urutan: asInt(json['urutan']),
      jumlahSoal: asInt(json['jumlah_soal']),
      status: (json['status'] ?? 'terkunci').toString(),
      tanggalSelesai: json['tanggal_selesai']?.toString(),
    );
  }
}
