import 'json_utils.dart';

class OpsiPilihan {
  const OpsiPilihan({required this.label, required this.teks});

  final String label;
  final String teks;

  factory OpsiPilihan.fromJson(dynamic json, int index) {
    if (json is Map) {
      return OpsiPilihan(
        label: (json['label'] ?? json['id'] ?? String.fromCharCode(65 + index)).toString(),
        teks: (json['teks'] ?? json['text'] ?? json['value'] ?? '').toString(),
      );
    }
    return OpsiPilihan(label: String.fromCharCode(65 + index), teks: json.toString());
  }
}

class Soal {
  const Soal({
    required this.id,
    required this.tipeSoal,
    required this.pertanyaan,
    this.levelMateriId,
    this.pembahasanId,
    this.opsiJawaban,
    this.kunciJawaban,
    this.mediaAudioUrl,
    this.mediaGambarUrl,
    this.bobotExp = 0,
    this.soalLatin,
    this.soalAksara,
    this.sudahDijawab = false,
    this.skorTertinggi = 0,
    this.lulus = false,
    this.jumlahPercobaan = 0,
  });

  final int id;
  final String tipeSoal;
  final String pertanyaan;
  final int? levelMateriId;
  final int? pembahasanId;
  final dynamic opsiJawaban;
  final dynamic kunciJawaban;
  final String? mediaAudioUrl;
  final String? mediaGambarUrl;
  final int bobotExp;
  final String? soalLatin;
  final String? soalAksara;

  /// Status pengerjaan milik siswa yang login (dari API website).
  final bool sudahDijawab;
  final int skorTertinggi;
  final bool lulus;
  final int jumlahPercobaan;

  static const tipePilihanGanda = 'pilihan_ganda';
  static const tipeSusunKalimat = 'susun_kalimat';
  static const tipePuzzle = 'puzzle_pakaian_adat';
  static const tipeMenulisAksara = 'menulis_aksara';
  static const tipeKuisSuara = 'kuis_suara';
  static const tipePencocokan = 'pencocokan_arti';

  /// Normalisasi tipe: puzzle dipetakan ke susun, pencocokan ke pilihan ganda.
  String get tipeEfektif {
    switch (tipeSoal) {
      case tipePuzzle:
        return tipePuzzle;
      case tipePencocokan:
        return tipePilihanGanda;
      default:
        return tipeSoal;
    }
  }

  List<OpsiPilihan> get opsiPilihan {
    final raw = opsiJawaban;
    if (raw is List) {
      return raw
          .asMap()
          .entries
          .map((e) => OpsiPilihan.fromJson(e.value, e.key))
          .toList();
    }
    return const [];
  }

  List<String> get opsiKata {
    final raw = opsiJawaban;
    if (raw is List) {
      return raw.map((e) {
        if (e is Map) return (e['teks'] ?? e['text'] ?? e['value'] ?? '').toString();
        return e.toString();
      }).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  String get teksReferensi {
    final k = kunciJawaban;
    if (k is Map) {
      final t = k['teks'] ?? k['jawaban'];
      if (t != null) return t.toString();
    }
    final o = opsiJawaban;
    if (o is Map && o['instruksi'] != null) return o['instruksi'].toString();
    return '';
  }

  String get aksara {
    final o = opsiJawaban;
    if (o is Map && o['aksara'] != null) return o['aksara'].toString();
    if (soalAksara != null && soalAksara!.isNotEmpty) return soalAksara!;
    return '';
  }

  String get petunjuk {
    final o = opsiJawaban;
    if (o is Map && o['petunjuk'] != null) return o['petunjuk'].toString();
    return 'Telusuri bayangan aksara.';
  }

  List<List<Map<String, double>>> get paths {
    final k = kunciJawaban;
    if (k is Map && k['paths'] is List) {
      final out = <List<Map<String, double>>>[];
      for (final stroke in (k['paths'] as List)) {
        if (stroke is List) {
          final pts = <Map<String, double>>[];
          for (final p in stroke) {
            if (p is Map) {
              pts.add({
                'x': asDouble(p['x']),
                'y': asDouble(p['y']),
              });
            } else if (p is List && p.length >= 2) {
              pts.add({'x': asDouble(p[0]), 'y': asDouble(p[1])});
            }
          }
          out.add(pts);
        }
      }
      return out;
    }
    return const [];
  }

  factory Soal.fromJson(Map<String, dynamic> json) {
    return Soal(
      id: asInt(json['id']),
      tipeSoal: (json['tipe_soal'] ?? 'pilihan_ganda').toString(),
      pertanyaan: (json['pertanyaan'] ?? '').toString(),
      levelMateriId: json['level_materi_id'] == null ? null : asInt(json['level_materi_id']),
      pembahasanId: json['pembahasan_id'] == null ? null : asInt(json['pembahasan_id']),
      opsiJawaban: json['opsi_jawaban'],
      kunciJawaban: json['kunci_jawaban'],
      mediaAudioUrl: json['media_audio_url']?.toString(),
      mediaGambarUrl: json['media_gambar_url']?.toString(),
      bobotExp: asInt(json['bobot_exp']),
      soalLatin: json['soal_latin']?.toString(),
      soalAksara: json['soal_aksara']?.toString(),
      sudahDijawab: json['sudah_dijawab'] == true,
      skorTertinggi: asInt(json['skor_tertinggi']),
      lulus: json['lulus'] == true,
      jumlahPercobaan: asInt(json['jumlah_percobaan']),
    );
  }
}
