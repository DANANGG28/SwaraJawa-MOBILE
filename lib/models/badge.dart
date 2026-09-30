import 'json_utils.dart';

/// Satu lencana hasil evaluasi backend (GET /badge).
class BadgeItem {
  const BadgeItem({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.deskripsi,
    required this.shape,
    required this.bgColor,
    required this.textColor,
    required this.icon,
    this.isUnlocked = false,
    this.progressPercent = 0,
    this.syaratText = '',
    this.earnedStatLeft = '',
    this.earnedStatRight = '',
  });

  final String id;
  final String nama;
  final String kategori;
  final String deskripsi;
  final String shape;
  final String bgColor;
  final String textColor;
  final String icon;
  final bool isUnlocked;
  final int progressPercent;
  final String syaratText;
  final String earnedStatLeft;
  final String earnedStatRight;

  factory BadgeItem.fromJson(Map<String, dynamic> json) {
    return BadgeItem(
      id: (json['id'] ?? '').toString(),
      nama: (json['nama'] ?? '').toString(),
      kategori: (json['kategori'] ?? '').toString(),
      deskripsi: (json['deskripsi'] ?? '').toString(),
      shape: (json['shape'] ?? 'clip-hexagon').toString(),
      bgColor: (json['bg_color'] ?? '#6C5CE8').toString(),
      textColor: (json['text_color'] ?? 'text-white').toString(),
      icon: (json['icon'] ?? 'military_tech').toString(),
      isUnlocked: json['is_unlocked'] == true,
      progressPercent: asInt(json['progress_percent']),
      syaratText: (json['syarat_text'] ?? '').toString(),
      earnedStatLeft: (json['earned_stat_left'] ?? '').toString(),
      earnedStatRight: (json['earned_stat_right'] ?? '').toString(),
    );
  }
}

/// Katalog lencana siswa (all/earned/locked + ringkasan).
class BadgeCatalog {
  const BadgeCatalog({
    this.all = const [],
    this.earned = const [],
    this.locked = const [],
    this.totalCount = 0,
    this.earnedCount = 0,
    this.completionPercentage = 0,
  });

  final List<BadgeItem> all;
  final List<BadgeItem> earned;
  final List<BadgeItem> locked;
  final int totalCount;
  final int earnedCount;
  final int completionPercentage;

  factory BadgeCatalog.fromJson(Map<String, dynamic> json) {
    List<BadgeItem> parse(dynamic value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((e) => BadgeItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return BadgeCatalog(
      all: parse(json['all']),
      earned: parse(json['earned']),
      locked: parse(json['locked']),
      totalCount: asInt(json['total_count']),
      earnedCount: asInt(json['earned_count']),
      completionPercentage: asInt(json['completion_percentage']),
    );
  }
}
