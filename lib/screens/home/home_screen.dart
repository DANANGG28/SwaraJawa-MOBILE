import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_shadows.dart';
import '../../models/bagian.dart';
import '../../models/level_materi.dart';
import '../../models/topik.dart';
import '../../state/app_state.dart';
import '../../widgets/bottom_nav.dart';
import '../profile/edit_profile_screen.dart';
import '../quiz/quiz_session_screen.dart';
import 'topik_list_screen.dart';

/// Beranda siswa — alur hierarki kurikulum:
/// Topik (dipilih) → Unit (banner ungu) → Bagian (node lingkaran) → Soal.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Topik> _topiks = const [];
  Topik? _topik;
  TopikDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _showWelcome = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _sessionKey(int? siswaId) => 'session_topik_id_${siswaId ?? 0}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      final topiks = await state.materi.daftarTopik();
      await state.refreshSiswa();

      final prefs = await SharedPreferences.getInstance();
      final key = _sessionKey(state.siswa?.id);
      final savedId = prefs.getInt(key);

      Topik? topik;
      if (_topik != null) {
        topik = topiks.where((t) => t.id == _topik!.id).firstOrNull;
      }
      if (topik == null && savedId != null) {
        topik = topiks.where((t) => t.id == savedId).firstOrNull;
      }
      // Alur persis website HomeController:
      // 1. Ambil topik dari session
      // 2. Jika belum ada, cari unit yang 'berjalan'
      // 3. Fallback ke topik pertama
      topik ??= topiks.where((t) => t.berjalan).firstOrNull ??
          (topiks.isNotEmpty ? topiks.first : null);

      TopikDetail? detail;
      if (topik != null) {
        await prefs.setInt(key, topik.id);
        detail = await state.materi.detailTopik(topik.id);
      }

      if (!mounted) return;
      setState(() {
        _topiks = topiks;
        _topik = topik;
        _detail = detail;
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

  Future<void> _pilihTopik(Topik topik) async {
    setState(() {
      _topik = topik;
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sessionKey(state.siswa?.id), topik.id);

      final detail = await state.materi.detailTopik(topik.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  Future<void> _openTopikPicker() async {
    final picked = await Navigator.of(context).push<Topik>(
      MaterialPageRoute(
        builder: (_) => TopikPickerScreen(topiks: _topiks, activeId: _topik?.id),
      ),
    );
    if (picked != null && mounted) await _pilihTopik(picked);
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
          const Icon(Symbols.cloud_off, size: 48, color: AppColors.gray400),
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

    if (_topik == null) {
      return TopikListContent(
        topiks: _topiks,
        activeId: null,
        onSelect: _pilihTopik,
      );
    }

    final siswa = state.siswa;
    final detail = _detail;
    final units = detail?.units ?? const <LevelMateri>[];
    final topik = detail?.topik ?? _topik!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        if (_showWelcome) _welcomeAlert(siswa?.namaLengkap ?? 'Siswa', siswa?.currentStreak ?? 0),
        if (siswa?.profilBelumLengkap == true) ...[
          const SizedBox(height: 16),
          _profilBanner(),
        ],
        const SizedBox(height: 20),
        if (units.isEmpty)
          _emptyCard()
        else
          ..._buildUnits(topik, units, siswa?.profilBelumLengkap == true),
      ],
    );
  }

  List<Widget> _buildUnits(Topik topik, List<LevelMateri> units, bool profilKurang) {
    final focusKey = _focusKey(units);
    final widgets = <Widget>[];

    for (var u = 0; u < units.length; u++) {
      final unit = units[u];
      widgets.add(_unitBanner(topik, unit, isFirst: u == 0));
      widgets.add(const SizedBox(height: 24));

      final specs = _nodeSpecs(unit, focusKey, profilKurang);
      widgets.add(_nodeChain(specs));
      widgets.add(const SizedBox(height: 18));
    }
    return widgets;
  }

  /// Kunci node yang menjadi fokus (menampilkan pill "MULAI") — node pertama
  /// yang terbuka dan belum rampung pada topik ini.
  String? _focusKey(List<LevelMateri> units) {
    for (final unit in units) {
      if (unit.terkunci) continue;
      if (unit.adaBagian) {
        for (final b in unit.pembahasan) {
          if (!b.selesai) return 'u${unit.id}b${b.id}';
        }
      } else if (!unit.selesai) {
        return 'u${unit.id}b0';
      }
    }
    return null;
  }

  List<_NodeSpec> _nodeSpecs(LevelMateri unit, String? focusKey, bool profilKurang) {
    final specs = <_NodeSpec>[];

    if (unit.adaBagian) {
      for (final bagian in unit.pembahasan) {
        final key = 'u${unit.id}b${bagian.id}';
        specs.add(_NodeSpec(
          title: bagian.nama,
          sub: '${bagian.persen}% • ${bagian.lulusCount}/${bagian.jumlahSoal} soal',
          locked: unit.terkunci || bagian.terkunci,
          done: bagian.selesai,
          active: !unit.terkunci && focusKey == key,
          onTap: () => _bukaBagian(unit, bagian, profilKurang),
        ));
      }
      return specs;
    }

    specs.add(_NodeSpec(
      title: unit.namaMateri,
      sub: '${unit.persen}% • ${unit.lulusCount}/${unit.jumlahSoal} soal',
      locked: unit.terkunci,
      done: unit.selesai,
      active: !unit.terkunci && focusKey == 'u${unit.id}b0',
      onTap: () => _bukaBagian(unit, null, profilKurang),
    ));
    return specs;
  }

  static const List<double> _xPattern = [0.5, 0.70, 0.30];

  Widget _nodeChain(List<_NodeSpec> specs) {
    if (specs.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cardW = math.min(238.0, w * 0.74);
        final minX = 38.0 + 16.0;
        final maxX = w - 38.0 - 16.0;

        double xFor(int i) {
          final frac = specs.length == 1 ? 0.5 : _xPattern[i % _xPattern.length];
          return (w * frac).clamp(minX, maxX);
        }

        return Column(
          children: [
            for (var i = 0; i < specs.length; i++) ...[
              if (i > 0)
                SizedBox(
                  height: 46,
                  width: w,
                  child: _DashedConnector(
                    fromX: xFor(i - 1),
                    toX: xFor(i),
                    done: specs[i - 1].done,
                  ),
                ),
              Column(
                children: [
                  SizedBox(
                    width: w,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: math.max(0, xFor(i) - 120)),
                        child: SizedBox(
                          width: 240,
                          child: Column(
                            children: [
                              if (specs[i].active) ...[
                                const _MulaiPill(),
                                const SizedBox(height: 10),
                              ],
                              _nodeCircle(specs[i]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SizedBox(
                      width: cardW,
                      child: _labelCard(specs[i]),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
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

  Widget _welcomeAlert(String nama, int streak) {
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
                  TextSpan(
                    text: streak > 0
                        ? 'Lanjutkan belajar hari ini untuk mempertahankan streak $streak hari.'
                        : 'Ayo mulai belajar hari ini dan raih streak pertamamu!',
                  ),
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
        boxShadow: AppShadows.card,
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
                border: Border.all(color: const Color(0xFFB45309), width: 2),
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

  Widget _unitBanner(Topik topik, LevelMateri unit, {required bool isFirst}) {
    final terkunci = unit.terkunci;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand600, AppColors.indigo600],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.brand700, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand600.withValues(alpha: 0.35),
            offset: const Offset(0, 10),
            blurRadius: 25,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          if (isFirst) ...[
            GestureDetector(
              onTap: _openTopikPicker,
              child: SizedBox(
                width: 30,
                height: 30,
                child: Icon(
                  Symbols.arrow_back,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UNIT ${topik.urutan}, BAGIAN ${unit.urutanUnit}',
                  style: AppFonts.nunito(
                    size: 10,
                    weight: FontWeight.w900,
                    color: const Color(0xFFC7D2FE),
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unit.namaMateri,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.nunito(size: 21, weight: FontWeight.w900, color: Colors.white, height: 1.15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(
              terkunci ? Symbols.lock : Symbols.play_arrow,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nodeCircle(_NodeSpec spec) {
    final Color fill;
    final Color edge;
    final Color iconColor;
    final IconData icon;

    if (spec.locked) {
      fill = AppColors.surfaceContainerHigh;
      edge = AppColors.gray200;
      iconColor = AppColors.gray400;
      icon = Symbols.lock;
    } else if (spec.done) {
      fill = const Color(0xFF10B981);
      edge = const Color(0xFF047857);
      iconColor = Colors.white;
      icon = Symbols.check;
    } else {
      fill = AppColors.brand600;
      edge = const Color(0xFF3730A3);
      iconColor = Colors.white;
      icon = Symbols.star;
    }

    return Semantics(
      button: true,
      enabled: !spec.locked,
      label: '${spec.title}, ${spec.locked ? 'terkunci' : (spec.done ? 'rampung' : 'mulai')}',
      child: GestureDetector(
        onTap: spec.onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: spec.locked
                ? null
                : LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [edge, fill],
                  ),
            color: spec.locked ? fill : null,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: spec.locked
                ? null
                : [
                    BoxShadow(color: edge, offset: const Offset(0, 6), blurRadius: 0),
                    BoxShadow(
                      color: fill.withValues(alpha: spec.active ? 0.45 : 0.25),
                      offset: const Offset(0, 12),
                      blurRadius: 20,
                    ),
                  ],
          ),
          child: Icon(icon, size: 36, color: iconColor),
        ),
      ),
    );
  }

  Widget _labelCard(_NodeSpec spec) {
    final subColor = spec.locked
        ? AppColors.gray400
        : (spec.done ? const Color(0xFF059669) : AppColors.brand600);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: spec.active ? const Color(0xFFD5CCFC) : AppColors.gray200,
          width: 1.5,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Text(
            spec.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.nunito(
              size: 12.5,
              weight: FontWeight.w900,
              color: spec.locked ? AppColors.gray500 : const Color(0xFF1E1B4B),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            spec.sub,
            textAlign: TextAlign.center,
            style: AppFonts.nunito(size: 10.5, weight: FontWeight.w800, color: subColor),
          ),
        ],
      ),
    );
  }

  void _bukaBagian(LevelMateri unit, Bagian? bagian, bool profilKurang) {
    if (unit.terkunci || (bagian?.terkunci ?? false)) {
      _showSnack('Materi belum tercapai. Selesaikan unit sebelumnya terlebih dahulu.');
      return;
    }
    if (profilKurang) {
      _openEditProfile();
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => QuizSessionScreen(level: unit, bagian: bagian),
        ))
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
        boxShadow: AppShadows.card,
      ),
      child: Text(
        'Belum ada unit materi ing topik iki.',
        style: AppFonts.nunito(size: 14, weight: FontWeight.w800, color: AppColors.gray500),
      ),
    );
  }
}

class _NodeSpec {
  const _NodeSpec({
    required this.title,
    required this.sub,
    required this.locked,
    required this.done,
    required this.active,
    required this.onTap,
  });

  final String title;
  final String sub;
  final bool locked;
  final bool done;
  final bool active;
  final VoidCallback onTap;
}

/// Pill "MULAI" melayang di atas node aktif, dengan ekor panah ke bawah.
class _MulaiPill extends StatefulWidget {
  const _MulaiPill();

  @override
  State<_MulaiPill> createState() => _MulaiPillState();
}

class _MulaiPillState extends State<_MulaiPill> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(scale: 1 + t * 0.045, child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.brand600,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand600.withValues(alpha: 0.4),
                  offset: const Offset(0, 6),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.play_arrow, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  'MULAI',
                  style: AppFonts.nunito(
                    size: 12,
                    weight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -2),
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(width: 10, height: 10, color: AppColors.brand600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Konektor belajar: garis abu putus-putus bergerak, hijau bila node
/// sebelumnya sudah rampung.
class _DashedConnector extends StatefulWidget {
  const _DashedConnector({
    required this.fromX,
    required this.toX,
    required this.done,
  });

  final double fromX;
  final double toX;
  final bool done;

  @override
  State<_DashedConnector> createState() => _DashedConnectorState();
}

class _DashedConnectorState extends State<_DashedConnector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _DashPainter(
            fromX: widget.fromX,
            toX: widget.toX,
            phase: _controller.value * 21.0,
            done: widget.done,
          ),
        );
      },
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({
    required this.fromX,
    required this.toX,
    required this.phase,
    required this.done,
  });

  final double fromX;
  final double toX;
  final double phase;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final path = Path()..moveTo(fromX, 0);
    if ((fromX - toX).abs() < 1) {
      path.lineTo(toX, size.height);
    } else {
      path.cubicTo(fromX, midY, toX, midY, toX, size.height);
    }

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.45);
    canvas.drawPath(path, base);

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = done ? const Color(0xFF10B981) : const Color(0xFFA79BFF);

    const dashLen = 12.0;
    const gapLen = 9.0;
    const period = dashLen + gapLen;
    for (final metric in path.computeMetrics()) {
      var distance = (phase % period) - period;
      while (distance < metric.length) {
        final start = distance.clamp(0.0, metric.length);
        final end = (distance + dashLen).clamp(0.0, metric.length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), dash);
        }
        distance += period;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) =>
      old.phase != phase ||
      old.fromX != fromX ||
      old.toX != toX ||
      old.done != done;
}
