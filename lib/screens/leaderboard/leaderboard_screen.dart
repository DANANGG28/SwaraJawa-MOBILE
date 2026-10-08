import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/leaderboard_entry.dart';
import '../../state/app_state.dart';
import '../../widgets/bottom_nav.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => LeaderboardScreenState();
}

class LeaderboardScreenState extends State<LeaderboardScreen> {
  String _scope = 'kelas';
  List<LeaderboardEntry> _entries = const [];
  LeaderboardEntry? _juaraSekolah;
  bool _loading = true;
  String? _error;

  /// Dipakai MainShell untuk memuat ulang saat tab Papan Peringkat dibuka.
  Future<void> reload() => _load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      final kelas = state.siswa?.kelas;
      if (_scope == 'kelas' && kelas != null && kelas.isNotEmpty) {
        _entries = await state.leaderboard.ambil(kelas: kelas);
        final sekolah = await state.leaderboard.ambil(limit: 1);
        _juaraSekolah = sekolah.isNotEmpty ? sekolah.first : null;
      } else {
        _entries = await state.leaderboard.ambil();
        _juaraSekolah = null;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final siswa = state.siswa;
    final kelas = siswa?.kelas;
    final myId = siswa?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SjMobileHeader(
              trailing: Row(
                children: [
                  _pill(
                    icon: Symbols.local_fire_department,
                    color: const Color(0xFFEA580C),
                    bg: const Color(0xFFFFF7ED),
                    border: const Color(0xFFFED7AA),
                    value: '${siswa?.currentStreak ?? 0}',
                  ),
                  const SizedBox(width: 8),
                  _pill(
                    icon: Symbols.bolt,
                    color: AppColors.brand600,
                    bg: const Color(0xFFF5F3FF),
                    border: const Color(0xFFDDD6FE),
                    value: '${siswa?.totalExp ?? 0}',
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary600,
                onRefresh: _load,
                child: _body(kelas, myId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppFonts.nunito(size: 12, weight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _body(String? kelas, int? myId) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary600));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 60),
          Text(
            'Gagal memuat papan skor.\n$_error',
            textAlign: TextAlign.center,
            style: AppFonts.manrope(size: 13, color: AppColors.gray500),
          ),
        ],
      );
    }

    final top1 = _entries.isNotEmpty ? _entries[0] : null;
    final top2 = _entries.length > 1 ? _entries[1] : null;
    final top3 = _entries.length > 2 ? _entries[2] : null;
    final others = _entries.length > 3 ? _entries.sublist(3, _entries.length > 8 ? 8 : _entries.length) : <LeaderboardEntry>[];
    final me = _entries.where((e) => e.siswaId == myId).toList();
    final myRank = me.isNotEmpty ? me.first.peringkat : (_entries.length + 1);
    final myExp = me.isNotEmpty ? me.first.totalExp : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _heroBanner(kelas),
        const SizedBox(height: 14),
        if (_scope == 'kelas' && _juaraSekolah != null) ...[
          _juaraSekolahBanner(_juaraSekolah!),
          const SizedBox(height: 14),
        ],
        _podiumCard(top1, top2, top3, kelas, myId),
        const SizedBox(height: 14),
        _listCard(others, kelas, myId),
        const SizedBox(height: 14),
        _myPositionCard(myRank, myExp, kelas, me.isNotEmpty ? me.first.streak : 0, myId),
      ],
    );
  }

  Widget _heroBanner(String? kelas) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary700, AppColors.primary600, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAPAN SKOR | ${_scope == 'sekolah' ? 'PERINGKAT SEKOLAH' : (kelas != null && kelas.isNotEmpty ? 'KELAS $kelas' : 'SEMUA KELAS')}',
            style: AppFonts.manrope(
              size: 10,
              weight: FontWeight.w800,
              color: AppColors.yellow300,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Papan Peringkat Siswa',
            style: AppFonts.epilogue(size: 20, weight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Lihat capaian poin (XP), streak pembelajaran, dan urutan peringkat siswa.',
            style: AppFonts.manrope(size: 12, color: AppColors.primaryFixed, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _scopeTab(
                  active: _scope == 'kelas',
                  icon: Symbols.groups,
                  label: 'Kelas ${kelas ?? '-'}',
                  onTap: () {
                    setState(() => _scope = 'kelas');
                    _load();
                  },
                ),
                _scopeTab(
                  active: _scope == 'sekolah',
                  icon: Symbols.school,
                  label: 'Sekolah',
                  onTap: () {
                    setState(() => _scope = 'sekolah');
                    _load();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeTab({
    required bool active,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: active ? AppColors.primary700 : Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppFonts.manrope(
                size: 13,
                weight: FontWeight.w800,
                color: active ? AppColors.primary700 : Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _juaraSekolahBanner(LeaderboardEntry juara) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: _avatar(juara, 40, 999),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JUARA 1 SEKOLAH',
                  style: AppFonts.manrope(
                    size: 10,
                    weight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  juara.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.epilogue(size: 15, weight: FontWeight.w800, color: Colors.white),
                ),
                Text(
                  juara.kelas != null ? 'Kelas ${juara.kelas}' : 'Siswa',
                  style: AppFonts.manrope(size: 11, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${juara.totalExp}',
                style: AppFonts.epilogue(size: 20, weight: FontWeight.w900, color: Colors.white),
              ),
              Text(
                'XP',
                style: AppFonts.manrope(
                  size: 10,
                  weight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podiumCard(
    LeaderboardEntry? top1,
    LeaderboardEntry? top2,
    LeaderboardEntry? top3,
    String? kelas,
    int? myId,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tiga Besar (Top 3)',
                  style: AppFonts.epilogue(size: 14, weight: FontWeight.w700),
                ),
              ),
              Text(
                _scope == 'sekolah' ? 'SEKOLAH' : 'KELAS ${kelas ?? 'SEMUA'}',
                style: AppFonts.manrope(
                  size: 10,
                  weight: FontWeight.w700,
                  color: AppColors.gray500,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.gray100),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _podiumColumn(top2, 2, myId)),
                Expanded(child: _podiumColumn(top1, 1, myId)),
                Expanded(child: _podiumColumn(top3, 3, myId)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _podiumColumn(LeaderboardEntry? entry, int rank, int? myId) {
    final colors = {
      2: AppColors.orange300,
      1: const Color(0xFF5443C9),
      3: AppColors.yellow300,
    };
    final heights = {1: 120.0, 2: 96.0, 3: 80.0};
    final labels = {1: 'JUARA 1', 2: 'RUNNER-UP', 3: 'PERINGKAT 3'};
    final ringColors = {
      1: AppColors.yellow300,
      2: AppColors.orange300.withValues(alpha: 0.4),
      3: AppColors.yellow300.withValues(alpha: 0.4),
    };
    final isMe = entry != null && entry.siswaId == myId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (rank == 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Symbols.emoji_events, size: 24, color: AppColors.yellow300),
            ),
          if (entry != null) ...[
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ringColors[rank],
                shape: BoxShape.circle,
              ),
              child: _avatar(entry, rank == 1 ? 56 : 48, 999),
            ),
            const SizedBox(height: 6),
            Text(
              entry.nama,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppFonts.epilogue(
                size: rank == 1 ? 13 : 11,
                weight: FontWeight.w800,
              ),
            ),
            Text(
              isMe ? '(Anda)' : (entry.kelas != null ? 'Kelas ${entry.kelas}' : 'Siswa'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.manrope(
                size: 10,
                weight: isMe ? FontWeight.w800 : FontWeight.w400,
                color: isMe ? AppColors.primary600 : AppColors.gray500,
              ),
            ),
            Text(
              '${entry.totalExp} XP',
              style: AppFonts.epilogue(
                size: rank == 1 ? 13 : 11,
                weight: FontWeight.w800,
                color: AppColors.primary700,
              ),
            ),
            const SizedBox(height: 6),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Belum ada',
                style: AppFonts.manrope(size: 11, color: AppColors.gray400),
              ),
            ),
          Container(
            height: heights[rank],
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors[rank],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                top: BorderSide(
                  color: rank == 1 ? AppColors.yellow300 : Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[rank]!,
                    style: AppFonts.manrope(
                      size: 8,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Text(
                  '$rank',
                  style: AppFonts.epilogue(
                    size: rank == 1 ? 42 : 30,
                    weight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listCard(List<LeaderboardEntry> others, String? kelas, int? myId) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daftar Peringkat Siswa Selanjutnya',
            style: AppFonts.epilogue(size: 14, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Peringkat ${_scope == 'sekolah' ? 'sekolah' : 'kelas ${kelas ?? ''}'} berdasarkan total XP',
            style: AppFonts.manrope(size: 11, color: AppColors.gray500),
          ),
          const Divider(height: 20, color: AppColors.gray100),
          if (others.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada siswa lainnya di papan skor.',
                  style: AppFonts.manrope(size: 12, color: AppColors.gray500),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                _th('Peringkat', flex: 2),
                _th('Siswa', flex: 4),
                _th('Kelas', flex: 2),
                _th('Total EXP', flex: 3, align: TextAlign.right),
              ],
            ),
            const SizedBox(height: 4),
            for (final item in others) _row(item, myId),
          ],
        ],
      ),
    );
  }

  Widget _th(String text, {int flex = 1, TextAlign align = TextAlign.left}) => Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: align,
          style: AppFonts.manrope(
            size: 10,
            weight: FontWeight.w800,
            color: AppColors.gray500,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _row(LeaderboardEntry item, int? myId) {
    final isMe = item.siswaId == myId;
    return Container(
      color: isMe ? AppColors.primary500.withValues(alpha: 0.1) : null,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${item.peringkat}',
                style: AppFonts.epilogue(size: 11, weight: FontWeight.w800, color: const Color(0xFF374151)),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                _avatar(item, 28, 999),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.nama}${isMe ? ' (Anda)' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.manrope(size: 12, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.kelas ?? '-',
              style: AppFonts.manrope(
                size: 12,
                weight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${item.totalExp} XP',
              textAlign: TextAlign.right,
              style: AppFonts.epilogue(size: 12, weight: FontWeight.w800, color: AppColors.primary700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _myPositionCard(int rank, int exp, String? kelas, int streak, int? myId) {
    final state = context.watch<AppState>();
    final nama = state.siswa?.namaLengkap ?? 'Siswa';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary500.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary500.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.primary600,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: AppFonts.epilogue(size: 12, weight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$nama (Posisi Anda)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.epilogue(size: 12, weight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary600,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'ANDA',
                        style: AppFonts.manrope(
                          size: 8,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${kelas != null && kelas.isNotEmpty ? 'Kelas $kelas' : 'Siswa'} • Streak $streak Hari',
                  style: AppFonts.manrope(size: 11, color: AppColors.gray500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$exp XP',
                style: AppFonts.epilogue(size: 14, weight: FontWeight.w900, color: AppColors.primary700),
              ),
              Text(
                'Peringkat #$rank',
                style: AppFonts.manrope(
                  size: 11,
                  weight: FontWeight.w700,
                  color: AppColors.green600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(LeaderboardEntry entry, double size, double radius) {
    if (entry.fotoUrl != null && entry.fotoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius == 999 ? size / 2 : radius),
        child: Image.network(
          entry.fotoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(entry, size, radius),
        ),
      );
    }
    return _initialsAvatar(entry, size, radius);
  }

  Widget _initialsAvatar(LeaderboardEntry entry, double size, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary700,
        borderRadius: BorderRadius.circular(radius == 999 ? size / 2 : radius),
      ),
      alignment: Alignment.center,
      child: Text(
        entry.inisial,
        style: AppFonts.epilogue(
          size: size * 0.34,
          weight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
