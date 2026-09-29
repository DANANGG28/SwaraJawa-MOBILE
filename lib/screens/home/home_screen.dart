import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_shadows.dart';
import '../../models/level_materi.dart';
import '../../state/app_state.dart';
import '../../widgets/bottom_nav.dart';
import '../profile/edit_profile_screen.dart';
import '../quiz/quiz_session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LevelMateri> _levels = const [];
  bool _loading = true;
  String? _error;
  bool _showWelcome = true;

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
      final levels = await state.materi.daftarMateri();
      await state.refreshSiswa();
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _loading = false;
      });
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

    return Scaffold(
      backgroundColor: AppColors.appBg,
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
                    bg: AppColors.primaryFixed.withValues(alpha: 0.6),
                    border: AppColors.primaryFixedDim,
                    value: '${siswa?.totalExp ?? 0}',
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary600,
                onRefresh: _load,
                child: _buildBody(state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppState state) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary600),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 60),
          Icon(Symbols.cloud_off, size: 48, color: AppColors.gray400),
          const SizedBox(height: 12),
          Text(
            'Gagal memuat materi',
            textAlign: TextAlign.center,
            style: AppFonts.nunito(size: 18, weight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppFonts.nunito(size: 13, color: AppColors.gray500),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary600),
              child: const Text('Coba Lagi'),
            ),
          ),
        ],
      );
    }

    final siswa = state.siswa;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_showWelcome) _welcomeAlert(siswa?.namaLengkap ?? 'Siswa'),
        if (siswa?.profilBelumLengkap == true) ...[
          const SizedBox(height: 16),
          _profilBanner(),
        ],
        const SizedBox(height: 20),
        if (_levels.isEmpty)
          _emptyCard()
        else
          for (final level in _levels) ...[
            _unitBanner(level),
            const SizedBox(height: 8),
            _roadmap(level),
            const SizedBox(height: 20),
          ],
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: AppFonts.nunito(size: 12, weight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _welcomeAlert(String nama) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
            child: const Icon(Symbols.check, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppFonts.nunito(size: 14, weight: FontWeight.w700, height: 1.4),
                children: [
                  TextSpan(
                    text: 'Selamat datang $nama! ',
                    style: AppFonts.nunito(size: 14, weight: FontWeight.w900, color: const Color(0xFF052E16)),
                  ),
                  TextSpan(text: 'Lanjutkan belajar hari ini untuk mempertahankan streak-mu.'),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showWelcome = false),
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Symbols.close, size: 18, color: Color(0xFF6EE7B7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFCD34D), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Symbols.assignment_late, size: 26, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Diri Belum Lengkap!',
                  style: AppFonts.nunito(size: 14, weight: FontWeight.w900, color: const Color(0xFF451A03)),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: AppFonts.nunito(size: 12, color: const Color(0xFF92400E)),
                    children: const [
                      TextSpan(text: 'Kamu perlu mengisi '),
                      TextSpan(text: 'Kelas', style: TextStyle(fontWeight: FontWeight.w900)),
                      TextSpan(text: ' dan '),
                      TextSpan(text: 'NIS', style: TextStyle(fontWeight: FontWeight.w900)),
                      TextSpan(text: ' sebelum dapat mengerjakan kuis.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openEditProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'LENGKAPI DATA',
                style: AppFonts.nunito(
                  size: 10,
                  weight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitBanner(LevelMateri level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand600, AppColors.indigo600],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brand700, width: 2),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UNIT ${level.urutan}',
                  style: AppFonts.nunito(
                    size: 11,
                    weight: FontWeight.w900,
                    color: AppColors.primaryFixedDim,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  level.namaMateri,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.nunito(size: 21, weight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(
              level.terkunci ? Symbols.lock : Symbols.play_arrow,
              size: 22,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roadmap(LevelMateri level) {
    final selesai = level.selesai;
    final terkunci = level.terkunci;

    final nodeColor = terkunci
        ? AppColors.gray200
        : (selesai ? const Color(0xFF10B981) : AppColors.brand600);
    final nodeIcon = terkunci
        ? Symbols.lock
        : (selesai ? Symbols.check : Symbols.star);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gray200, width: 2),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _bukaLevel(level),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: terkunci ? null : AppShadows.md,
                  ),
                  child: Icon(nodeIcon, size: 34, color: Colors.white),
                ),
              ),
              if (selesai)
                Positioned(
                  top: -6,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'RAMPUNG',
                      style: AppFonts.nunito(
                        size: 9,
                        weight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              if (level.berjalan)
                Positioned(
                  top: -34,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.brand600,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.play_arrow, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'MULAI',
                          style: AppFonts.nunito(
                            size: 11,
                            weight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: level.berjalan ? AppColors.primaryFixedDim : AppColors.gray200,
                width: 2,
              ),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                Text(
                  level.namaMateri,
                  textAlign: TextAlign.center,
                  style: AppFonts.nunito(
                    size: 13,
                    weight: FontWeight.w900,
                    color: terkunci
                        ? AppColors.gray500
                        : (level.berjalan ? AppColors.primary950 : AppColors.onSurface),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  terkunci
                      ? 'Terkunci'
                      : (selesai
                          ? '${level.jumlahSoal}/${level.jumlahSoal} • Rampung'
                          : '${level.jumlahSoal} soal • Hadiah +${level.rewardExp} XP'),
                  textAlign: TextAlign.center,
                  style: AppFonts.nunito(
                    size: 11,
                    weight: FontWeight.w800,
                    color: terkunci
                        ? AppColors.gray400
                        : (selesai ? const Color(0xFF059669) : AppColors.brand600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _bukaLevel(LevelMateri level) {
    if (level.terkunci) {
      _showSnack('Materi belum tercapai. Selesaikan unit sebelumnya terlebih dahulu.');
      return;
    }
    if (context.read<AppState>().siswa?.profilBelumLengkap == true) {
      _openEditProfile();
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => QuizSessionScreen(level: level)))
        .then((_) => _load());
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    _load();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gray200, width: 2),
      ),
      child: Text(
        'Belum ada unit materi sing kasedhiya.',
        style: AppFonts.nunito(size: 14, weight: FontWeight.w800, color: AppColors.gray500),
      ),
    );
  }
}
