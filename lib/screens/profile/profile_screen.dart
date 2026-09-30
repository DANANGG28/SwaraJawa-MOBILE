import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/badge.dart';
import '../../models/leaderboard_entry.dart';
import '../../models/progres.dart';
import '../../core/network/api_exception.dart';
import '../../state/app_state.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  String _tab = 'badge';
  ProgresData? _progres;
  BadgeCatalog _badges = const BadgeCatalog();
  int _myRank = 0;
  bool _loading = true;

  /// Dipakai MainShell untuk memuat ulang saat tab Profil dibuka.
  Future<void> reload() => _load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final state = context.read<AppState>();
      final progres = await state.progres.ambil();
      await state.refreshSiswa();
      List<LeaderboardEntry> board = const [];
      try {
        board = await state.leaderboard.ambil(limit: 100);
      } on ApiException {
        board = const [];
      }
      BadgeCatalog badges = const BadgeCatalog();
      try {
        badges = await state.badge.ambil();
      } on ApiException {
        badges = const BadgeCatalog();
      }
      final myId = state.siswa?.id;
      final myIndex = board.indexWhere((e) => e.siswaId == myId);
      if (!mounted) return;
      setState(() {
        _progres = progres;
        _badges = badges;
        _myRank = myIndex >= 0 ? board[myIndex].peringkat : 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final siswa = state.siswa;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary600,
                onRefresh: _load,
                child: _loading || siswa == null
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary600))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
                        children: [
                          _profileCard(siswa),
                          const SizedBox(height: 16),
                          _logoutButton(),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xE6FFFFFF),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.gray200.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.search, size: 20, color: AppColors.gray500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cari materi aksara, peribahasa, tata bahasa...',
                      style: AppFonts.manrope(size: 12, color: AppColors.gray500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.gray50, shape: BoxShape.circle),
                child: const Icon(Symbols.notifications, size: 20, color: AppColors.onSurfaceVariant),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmLogout(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.gray50, shape: BoxShape.circle),
              child: const Icon(Symbols.logout, size: 20, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(dynamic siswa) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gray100),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroBanner(siswa),
          _statsSection(siswa),
          _tabsBar(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _tab == 'badge' ? _badgePanel(siswa) : _akademikPanel(siswa),
          ),
        ],
      ),
    );
  }

  Widget _heroBanner(dynamic siswa) {
    final fotoUrl = _fotoUrl(siswa);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary700, AppColors.primary600, AppColors.primary500],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.school, size: 16, color: Color(0xE6FFFFFF)),
              const SizedBox(width: 6),
              Text(
                'PORTAL BELAJAR SISWA • SINAU JOWO',
                style: AppFonts.manrope(
                  size: 10,
                  weight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: fotoUrl.isNotEmpty
                          ? Image.network(
                              fotoUrl,
                              width: 74,
                              height: 74,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarInitials(siswa),
                            )
                          : _avatarInitials(siswa),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.green400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            siswa.namaLengkap,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.epilogue(
                              size: 20,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Symbols.verified, size: 18, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIS: ${siswa.nis ?? '-'}  •  KELAS ${(siswa.kelas ?? 'SISWA').toString().toUpperCase()}  •  SINAU JOWO',
                      style: AppFonts.manrope(
                        size: 11,
                        weight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Siswa rajin mempelajari tata krama bahasa dan aksara Jawa.',
                      style: AppFonts.manrope(
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
              _load();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -1),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    siswa.dataDiriLengkap ? Symbols.edit_square : Symbols.assignment_ind,
                    size: 18,
                    color: AppColors.primary700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    siswa.dataDiriLengkap ? 'Edit Data Diri' : 'Lengkapi Data Diri',
                    style: AppFonts.manrope(
                      size: 13,
                      weight: FontWeight.w800,
                      color: AppColors.primary700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarInitials(dynamic siswa) {
    return Container(
      color: Colors.white.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Text(
        siswa.inisial as String,
        style: AppFonts.epilogue(size: 24, weight: FontWeight.w800, color: Colors.white),
      ),
    );
  }

  String _fotoUrl(dynamic siswa) {
    final raw = siswa.fotoUrl as String?;
    if (raw == null || raw.isEmpty) return '';
    return AppConfig.resolveUrl(raw);
  }

  Widget _statsSection(dynamic siswa) {
    final ringkasan = _progres?.ringkasan;
    final exp = siswa.totalExp as int;
    final tingkat = exp >= 1000
        ? 'Tingkat: Wasasis (Mahir)'
        : (exp >= 300 ? 'Tingkat: Madya' : 'Tingkat: Pratama (Pemula)');
    final completed = ringkasan?.levelSelesai ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.gray100)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryFixed),
        ),
        child: Column(
          children: [
            _statRow(
              icon: Symbols.stars,
              iconBg: AppColors.primaryFixed,
              iconColor: AppColors.primary700,
              label: 'Total Poin Belajar',
              valueWidget: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$exp', style: AppFonts.epilogue(size: 20, weight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  Text('XP', style: AppFonts.manrope(size: 12, weight: FontWeight.w800, color: AppColors.primary600)),
                ],
              ),
              sub: tingkat,
            ),
            const SizedBox(height: 12),
            _statRow(
              icon: Symbols.military_tech,
              iconBg: AppColors.yellow300.withValues(alpha: 0.4),
              iconColor: const Color(0xFF92400E),
              label: 'Peringkat Pembelajaran',
              valueWidget: Text('#$_myRank', style: AppFonts.epilogue(size: 20, weight: FontWeight.w800)),
              subColor: AppColors.green600,
              sub: '$completed Level Selesai',
            ),
            const SizedBox(height: 12),
            _statRow(
              icon: Symbols.local_fire_department,
              iconBg: AppColors.orange300.withValues(alpha: 0.4),
              iconColor: const Color(0xFFEA580C),
              label: 'Streak Konsistensi',
              valueWidget: Text('${siswa.currentStreak} Hari', style: AppFonts.epilogue(size: 20, weight: FontWeight.w800)),
              sub: 'Rekor tertinggi: ${siswa.highestStreak} Hari',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required Widget valueWidget,
    required String sub,
    Color subColor = AppColors.gray500,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppFonts.manrope(
                  size: 10,
                  weight: FontWeight.w800,
                  color: AppColors.gray500,
                  letterSpacing: 0.8,
                ),
              ),
              valueWidget,
              Text(
                sub,
                style: AppFonts.manrope(size: 10, weight: FontWeight.w600, color: subColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabsBar() {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.gray200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _tabButton('badge', 'Koleksi Badge & Piagam', Symbols.workspace_premium),
          const SizedBox(width: 16),
          _tabButton('akademik', 'Rincian Profil & Akademik', Symbols.school),
        ],
      ),
    );
  }

  Widget _tabButton(String key, String label, IconData icon) {
    final active = _tab == key;
    return GestureDetector(
      onTap: () => setState(() => _tab = key),
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary600 : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? AppColors.primary600 : AppColors.gray500),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppFonts.epilogue(
                size: 12,
                weight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? AppColors.primary600 : AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgePanel(dynamic siswa) {
    final earned = _badges.earned.map(_toBadgeData).toList();
    final locked = _badges.locked.map(_toBadgeData).toList();
    final completed = _badges.earnedCount;
    final total = _badges.totalCount;
    final persen = _badges.completionPercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryFixed),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Koleksi Piagam & Lencana Belajar', style: AppFonts.epilogue(size: 14, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Lencana otomatis diraih ketika menyelesaikan penelusuran aksara, percakapan krama, dan kuis kebudayaan.',
                style: AppFonts.manrope(size: 12, color: AppColors.gray500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray100),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progres Pembelajaran', style: AppFonts.manrope(size: 11, weight: FontWeight.w600, color: AppColors.gray500)),
                        Text(
                          '$completed dari $total Lencana ($persen%)',
                          style: AppFonts.manrope(size: 11, weight: FontWeight.w800, color: AppColors.primary600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 8,
                        color: AppColors.gray200.withValues(alpha: 0.8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (persen / 100).clamp(0.0, 1.0),
                            child: Container(color: AppColors.primary600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(Symbols.verified, size: 16, color: AppColors.green500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Lencana yang Telah Diraih ($completed)',
                style: AppFonts.epilogue(size: 12, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final b in earned) _badgeCard(b, locked: false),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Symbols.lock, size: 16, color: AppColors.gray500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Lencana yang Masih Terkunci (${locked.length})',
                style: AppFonts.epilogue(size: 12, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final b in locked) _badgeCard(b, locked: true),
      ],
    );
  }

  _BadgeData _toBadgeData(BadgeItem b) {
    final locked = !b.isUnlocked;
    return _BadgeData(
      b.nama,
      _badgeShape(b.shape),
      locked ? AppColors.gray200 : _hexColor(b.bgColor),
      locked ? AppColors.gray500 : _badgeTextColor(b.textColor),
      _badgeIcon(b.icon),
      '${b.kategori} • ${locked ? 'TERKUNCI' : 'SELESAI'}',
      b.deskripsi,
      locked ? b.syaratText : b.earnedStatLeft,
      locked ? '' : b.earnedStatRight,
      progress: locked ? b.progressPercent : 100,
    );
  }

  static _BadgeShape _badgeShape(String shape) {
    switch (shape) {
      case 'clip-pentagon':
        return _BadgeShape.pentagon;
      case 'clip-shield':
        return _BadgeShape.shield;
      case 'clip-rhombus':
        return _BadgeShape.rhombus;
      case 'clip-octagon':
        return _BadgeShape.octagon;
      case 'clip-hexagon':
      default:
        return _BadgeShape.hexagon;
    }
  }

  static Color _hexColor(String hex) {
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? AppColors.primary600 : Color(v);
  }

  static Color _badgeTextColor(String token) {
    switch (token) {
      case 'text-white':
        return Colors.white;
      case 'text-amber-950':
        return const Color(0xFF451A03);
      case 'text-amber-900':
        return const Color(0xFF78350F);
      case 'text-gray-500':
        return AppColors.gray500;
      default:
        return Colors.white;
    }
  }

  static IconData _badgeIcon(String name) {
    const map = <String, IconData>{
      'mic': Symbols.mic,
      'history_edu': Symbols.history_edu,
      'verified': Symbols.verified,
      'format_list_numbered': Symbols.format_list_numbered,
      'theater_comedy': Symbols.theater_comedy,
      'record_voice_over': Symbols.record_voice_over,
      'auto_stories': Symbols.auto_stories,
      'psychology': Symbols.psychology,
      'local_fire_department': Symbols.local_fire_department,
      'stars': Symbols.stars,
      'flag': Symbols.flag,
    };
    return map[name] ?? Symbols.military_tech;
  }

  Widget _badgeCard(_BadgeData b, {required bool locked}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: locked ? Colors.white.withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: locked ? AppColors.gray200 : AppColors.gray100),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
      child: Column(
        children: [
          ClipPath(
            clipper: _BadgeClipper(b.shape),
            child: Container(
              width: 64,
              height: 64,
              color: b.color,
              alignment: Alignment.center,
              child: Icon(
                locked ? Symbols.lock : b.icon,
                size: 30,
                color: b.iconColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            b.meta,
            style: AppFonts.manrope(
              size: 10,
              weight: FontWeight.w800,
              color: AppColors.gray500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(b.title, textAlign: TextAlign.center, style: AppFonts.epilogue(size: 14, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            b.description,
            textAlign: TextAlign.center,
            style: AppFonts.manrope(
              size: 12,
              color: locked ? AppColors.gray500 : AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryFixed),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    b.footer,
                    style: AppFonts.manrope(size: 11, color: AppColors.gray500),
                  ),
                ),
                if (b.footerValue.isNotEmpty)
                  Text(
                    b.footerValue,
                    style: AppFonts.epilogue(size: 11, weight: FontWeight.w800, color: AppColors.primary700),
                  ),
              ],
            ),
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 6,
                      color: AppColors.gray200.withValues(alpha: 0.8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (b.progress / 100).clamp(0.0, 1.0),
                          child: Container(color: AppColors.primary500),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${b.progress}%',
                  style: AppFonts.manrope(size: 10, weight: FontWeight.w800, color: AppColors.primary600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _akademikPanel(dynamic siswa) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoCard(
          icon: Symbols.person,
          title: 'Data Pribadi Siswa',
          trailing: Text(
            'AKTIF',
            style: AppFonts.manrope(size: 10, weight: FontWeight.w800, color: AppColors.primary600, letterSpacing: 0.8),
          ),
          rows: [
            ('Nama Lengkap', siswa.namaLengkap),
            ('Nomor Induk Siswa (NIS)', siswa.nis ?? '-'),
            ('Jenis Kelamin', siswa.jenisKelaminLabel),
            ('Kelas', siswa.kelas != null ? 'Kelas ${siswa.kelas}' : '-'),
            ('Email Akun Belajar', siswa.email ?? '-'),
            ('No. Telepon', siswa.noTelpon ?? '-'),
          ],
        ),
        const SizedBox(height: 16),
        _infoCard(
          icon: Symbols.school,
          title: 'Informasi Akademik & Sekolah',
          trailing: Text(
            'AKTIF',
            style: AppFonts.manrope(size: 10, weight: FontWeight.w800, color: AppColors.primary600, letterSpacing: 0.8),
          ),
          rows: const [
            ('Asal Sekolah', 'Sinau Jowo Academy'),
            ('Kurikulum & Muatan', 'Bahasa, Sastra & Aksara Jawa'),
            ('Tahun Ajaran', '2024 / 2025'),
            ('Semester Aktif', 'Semester Ganjil'),
          ],
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _confirmLogout(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray200, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.logout, size: 20, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Text(
                  'KELUAR',
                  style: AppFonts.epilogue(
                    size: 13,
                    weight: FontWeight.w800,
                    color: const Color(0xFFDC2626),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required List<(String, String)> rows,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppFonts.epilogue(size: 13, weight: FontWeight.w800)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          for (final row in rows) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gray100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.$1,
                    style: AppFonts.manrope(size: 11, weight: FontWeight.w500, color: AppColors.gray500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.$2,
                    style: AppFonts.manrope(size: 13, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return GestureDetector(
      onTap: () => _confirmLogout(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.logout, size: 20, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text(
              'KELUAR DARI AKUN',
              style: AppFonts.epilogue(
                size: 13,
                weight: FontWeight.w800,
                color: const Color(0xFFDC2626),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda akan kembali ke halaman masuk.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppState>().logout();
    }
  }
}

enum _BadgeShape { hexagon, pentagon, shield, rhombus, octagon }

class _BadgeData {
  const _BadgeData(
    this.title,
    this.shape,
    this.color,
    this.iconColor,
    this.icon,
    this.meta,
    this.description,
    this.footer,
    this.footerValue, {
    this.progress = 0,
  });

  final String title;
  final _BadgeShape shape;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final String meta;
  final String description;
  final String footer;
  final String footerValue;
  final int progress;
}

class _BadgeClipper extends CustomClipper<Path> {
  _BadgeClipper(this.shape);

  final _BadgeShape shape;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    switch (shape) {
      case _BadgeShape.hexagon:
        return Path()
          ..addPolygon([
            Offset(w * 0.25, 0),
            Offset(w * 0.75, 0),
            Offset(w, h * 0.5),
            Offset(w * 0.75, h),
            Offset(w * 0.25, h),
            Offset(0, h * 0.5),
          ], true);
      case _BadgeShape.pentagon:
        return Path()
          ..addPolygon([
            Offset(w * 0.5, 0),
            Offset(w, h * 0.38),
            Offset(w * 0.81, h),
            Offset(w * 0.19, h),
            Offset(0, h * 0.38),
          ], true);
      case _BadgeShape.shield:
        return Path()
          ..addPolygon([
            Offset(w * 0.5, 0),
            Offset(w, h * 0.25),
            Offset(w, h * 0.75),
            Offset(w * 0.5, h),
            Offset(0, h * 0.75),
            Offset(0, h * 0.25),
          ], true);
      case _BadgeShape.rhombus:
        return Path()
          ..addPolygon([
            Offset(w * 0.5, 0),
            Offset(w, h * 0.5),
            Offset(w * 0.5, h),
            Offset(0, h * 0.5),
          ], true);
      case _BadgeShape.octagon:
        return Path()
          ..addPolygon([
            Offset(w * 0.3, 0),
            Offset(w * 0.7, 0),
            Offset(w, h * 0.3),
            Offset(w, h * 0.7),
            Offset(w * 0.7, h),
            Offset(w * 0.3, h),
            Offset(0, h * 0.7),
            Offset(0, h * 0.3),
          ], true);
    }
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
