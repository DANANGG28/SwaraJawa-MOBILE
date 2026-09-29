import 'json_utils.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.peringkat,
    required this.siswaId,
    required this.nama,
    this.kelas,
    this.fotoUrl,
    this.totalExp = 0,
    this.streak = 0,
  });

  final int peringkat;
  final int siswaId;
  final String nama;
  final String? kelas;
  final String? fotoUrl;
  final int totalExp;
  final int streak;

  String get inisial {
    final words =
        nama.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return (words.first.substring(0, 1) + words.last.substring(0, 1))
          .toUpperCase();
    }
    if (nama.isEmpty) return 'SJ';
    return nama.substring(0, nama.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      peringkat: asInt(json['peringkat']),
      siswaId: asInt(json['siswa_id'] ?? json['id']),
      nama: (json['nama'] ?? json['nama_lengkap'] ?? '-').toString(),
      kelas: json['kelas']?.toString(),
      fotoUrl: json['foto_url']?.toString(),
      totalExp: asInt(json['total_exp']),
      streak: asInt(json['streak']),
    );
  }
}
