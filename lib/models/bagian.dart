import 'json_utils.dart';

/// Bagian (pembahasan) — sub-materi di dalam satu unit.
///
/// Hierarki kurikulum: Topik → Unit → **Bagian** → Soal.
class Bagian {
  const Bagian({
    required this.id,
    required this.nama,
    this.deskripsi,
    this.urutan = 0,
    this.jumlahSoal = 0,
    this.lulusCount = 0,
    this.persen = 0,
    this.status = 'anyar',
    this.terkunci = false,
  });

  final int id;
  final String nama;
  final String? deskripsi;
  final int urutan;
  final int jumlahSoal;
  final int lulusCount;
  final int persen;
  final String status;
  final bool terkunci;

  bool get selesai => status == 'selesai';
  bool get berjalan => status == 'berjalan';
  bool get anyar => status == 'anyar';

  factory Bagian.fromJson(Map<String, dynamic> json) {
    return Bagian(
      id: asInt(json['id']),
      nama: (json['nama'] ?? '').toString(),
      deskripsi: json['deskripsi']?.toString(),
      urutan: asInt(json['urutan']),
      jumlahSoal: asInt(json['jumlah_soal']),
      lulusCount: asInt(json['lulus_count']),
      persen: asInt(json['persen']),
      status: (json['status'] ?? 'anyar').toString(),
      terkunci: json['terkunci'] == true,
    );
  }
}
