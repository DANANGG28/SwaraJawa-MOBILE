class ExpInfo {
  const ExpInfo({this.totalExp = 0});

  final int totalExp;

  factory ExpInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ExpInfo();
    return ExpInfo(totalExp: _asInt(json['total_exp']));
  }
}

class StrekInfo {
  const StrekInfo({
    this.currentStreak = 0,
    this.highestStreak = 0,
    this.lastActivityDate,
  });

  final int currentStreak;
  final int highestStreak;
  final String? lastActivityDate;

  factory StrekInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StrekInfo();
    return StrekInfo(
      currentStreak: _asInt(json['current_streak']),
      highestStreak: _asInt(json['highest_streak']),
      lastActivityDate: json['last_activity_date']?.toString(),
    );
  }

  StrekInfo copyWith({int? currentStreak, int? highestStreak}) => StrekInfo(
        currentStreak: currentStreak ?? this.currentStreak,
        highestStreak: highestStreak ?? this.highestStreak,
        lastActivityDate: lastActivityDate,
      );
}

class Siswa {
  const Siswa({
    required this.id,
    required this.namaLengkap,
    this.nis,
    this.jenisKelamin,
    this.kelas,
    this.noTelpon,
    this.email,
    this.foto,
    this.fotoUrl,
    this.createdAt,
    this.exp = const ExpInfo(),
    this.strek = const StrekInfo(),
  });

  final int id;
  final String namaLengkap;
  final String? nis;
  final String? jenisKelamin;
  final String? kelas;
  final String? noTelpon;
  final String? email;
  final String? foto;
  final String? fotoUrl;
  final String? createdAt;
  final ExpInfo exp;
  final StrekInfo strek;

  int get totalExp => exp.totalExp;
  int get currentStreak => strek.currentStreak;
  int get highestStreak => strek.highestStreak;

  String get inisial {
    final words = namaLengkap.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return (words.first.substring(0, 1) + words.last.substring(0, 1)).toUpperCase();
    }
    return namaLengkap.isEmpty
        ? 'SJ'
        : namaLengkap.substring(0, namaLengkap.length >= 2 ? 2 : 1).toUpperCase();
  }

  bool get profilBelumLengkap =>
      (kelas == null || kelas!.trim().isEmpty) || (nis == null || nis!.trim().isEmpty);

  bool get dataDiriLengkap =>
      foto != null &&
      foto!.isNotEmpty &&
      nis != null &&
      nis!.isNotEmpty &&
      noTelpon != null &&
      noTelpon!.isNotEmpty &&
      jenisKelamin != null &&
      jenisKelamin!.isNotEmpty;

  String get jenisKelaminLabel {
    switch (jenisKelamin) {
      case 'L':
        return 'Laki-laki (L)';
      case 'P':
        return 'Perempuan (P)';
      default:
        return '-';
    }
  }

  Siswa copyWith({
    String? nis,
    String? namaLengkap,
    String? jenisKelamin,
    String? kelas,
    String? noTelpon,
    String? email,
    String? foto,
    String? fotoUrl,
    ExpInfo? exp,
    StrekInfo? strek,
  }) =>
      Siswa(
        id: id,
        namaLengkap: namaLengkap ?? this.namaLengkap,
        nis: nis ?? this.nis,
        jenisKelamin: jenisKelamin ?? this.jenisKelamin,
        kelas: kelas ?? this.kelas,
        noTelpon: noTelpon ?? this.noTelpon,
        email: email ?? this.email,
        foto: foto ?? this.foto,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        createdAt: createdAt,
        exp: exp ?? this.exp,
        strek: strek ?? this.strek,
      );

  factory Siswa.fromJson(Map<String, dynamic> json) {
    return Siswa(
      id: _asInt(json['id']),
      namaLengkap: (json['nama_lengkap'] ?? 'Siswa').toString(),
      nis: json['nis']?.toString(),
      jenisKelamin: json['jenis_kelamin']?.toString(),
      kelas: json['kelas']?.toString(),
      noTelpon: json['no_telpon']?.toString(),
      email: json['email']?.toString(),
      foto: json['foto']?.toString(),
      fotoUrl: json['foto_url']?.toString(),
      createdAt: json['created_at']?.toString(),
      exp: ExpInfo.fromJson(json['exp'] is Map ? Map<String, dynamic>.from(json['exp']) : null),
      strek: StrekInfo.fromJson(json['strek'] is Map ? Map<String, dynamic>.from(json['strek']) : null),
    );
  }
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}
