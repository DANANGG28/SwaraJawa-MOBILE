import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../models/soal.dart';

TextStyle _guideStyle(double fontSize, Color color) =>
    AppFonts.javanese(size: fontSize, color: color);

/// Fraksi kanvas yang ditempati aksara panduan (1.0 = mentok tepi).
const double kGuideFill = 0.94;

/// Ukuran font acuan saat mengukur metrik raster aksara.
const double _refFontSize = 256;

/// Metrik aksara dalam satuan em (per 1 px ukuran font): box layout yang
/// dilaporkan TextPainter beserta bbox ink di dalamnya.
///
/// Font aksara Jawa (mis. Noto Sans Javanese) menyediakan ruang vertikal
/// untuk sandhangan bertumpuk, sehingga box layout jauh lebih tinggi dari
/// bentuk aksara itu sendiri. Memakai box layout sebagai dasar penskalaan
/// membuat panduan tampak kecil di kanvas, jadi yang dipakai adalah bbox ink.
class GuideMetrics {
  const GuideMetrics({
    required this.boxW,
    required this.boxH,
    required this.inkLeft,
    required this.inkTop,
    required this.inkW,
    required this.inkH,
  });

  final double boxW;
  final double boxH;
  final double inkLeft;
  final double inkTop;
  final double inkW;
  final double inkH;
}

/// Posisi dan ukuran aksara panduan di kanvas. Dipakai bersama oleh painter
/// (menggambar) dan normalisasi goresan (kirim ke backend) agar keduanya
/// tidak pernah memakai box berbeda.
class GuideGeometry {
  const GuideGeometry({
    required this.ink,
    required this.paintOffset,
    required this.fontSize,
  });

  /// Rect ink aksara di koordinat kanvas — box normalisasi goresan sekaligus
  /// acuan pemetaan `kunci_jawaban.paths`.
  final Rect ink;

  /// Titik gambar box layout TextPainter (ascent/descent termasuk di atasnya).
  final Offset paintOffset;

  final double fontSize;
}

final Map<String, GuideMetrics> _guideMetrics = <String, GuideMetrics>{};
final Set<String> _guideMetricsPending = <String>{};
final Set<String> _guideMetricsFailed = <String>{};

/// Metrik raster [guide] bila sudah terukur, null bila belum/tak terukur.
GuideMetrics? guideMetricsFor(String guide) => _guideMetrics[guide];

/// Ukur bbox ink [guide] sekali per string lalu simpan di cache proses.
/// Mengembalikan true bila cache bertambah (pemanggil perlu repaint).
Future<bool> ensureGuideMetrics(String guide) async {
  if (guide.isEmpty ||
      _guideMetrics.containsKey(guide) ||
      _guideMetricsPending.contains(guide) ||
      _guideMetricsFailed.contains(guide)) {
    return false;
  }
  _guideMetricsPending.add(guide);
  try {
    final metrics = await _measureGuideMetrics(guide);
    if (metrics == null) {
      _guideMetricsFailed.add(guide);
      return false;
    }
    _guideMetrics[guide] = metrics;
    return true;
  } catch (_) {
    // Raster tak tersedia (mis. binding tanpa GPU): pakai box layout.
    _guideMetricsFailed.add(guide);
    return false;
  } finally {
    _guideMetricsPending.remove(guide);
  }
}

Future<GuideMetrics?> _measureGuideMetrics(String guide) async {
  final tp = TextPainter(
    text: TextSpan(text: guide, style: _guideStyle(_refFontSize, Colors.white)),
    textDirection: TextDirection.ltr,
  )..layout();
  final w = tp.width.ceil() + 2;
  final h = tp.height.ceil() + 2;
  if (w <= 2 || h <= 2) return null;

  final recorder = ui.PictureRecorder();
  tp.paint(Canvas(recorder), const Offset(1, 1));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  if (data == null) return null;

  final bytes = data.buffer.asUint8List();
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    final row = y * w * 4;
    for (var x = 0; x < w; x++) {
      if (bytes[row + x * 4 + 3] > 8) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;

  const k = 1 / _refFontSize;
  return GuideMetrics(
    boxW: tp.width * k,
    boxH: tp.height * k,
    inkLeft: (minX - 1) * k,
    inkTop: (minY - 1) * k,
    inkW: (maxX - minX + 1) * k,
    inkH: (maxY - minY + 1) * k,
  );
}

/// Geometri panduan untuk [canvasSize]. Metrik ink sudah terukur → aksara
/// diskalakan hampir memenuhi sisi pembatas kanvas. Belum terukur → mundur ke
/// box layout TextPainter yang dipaskan ke kanvas.
GuideGeometry guideGeometryFor(Size canvasSize, String guide) {
  if (guide.isEmpty || canvasSize.width <= 0 || canvasSize.height <= 0) {
    return const GuideGeometry(ink: Rect.zero, paintOffset: Offset.zero, fontSize: 0);
  }

  final m = _guideMetrics[guide];
  if (m != null && m.inkW > 0 && m.inkH > 0) {
    final fontSize = math.min(
      canvasSize.width * kGuideFill / m.inkW,
      canvasSize.height * kGuideFill / m.inkH,
    );
    final inkW = m.inkW * fontSize;
    final inkH = m.inkH * fontSize;
    final left = (canvasSize.width - inkW) / 2;
    final top = (canvasSize.height - inkH) / 2;
    return GuideGeometry(
      ink: Rect.fromLTWH(left, top, inkW, inkH),
      paintOffset: Offset(left - m.inkLeft * fontSize, top - m.inkTop * fontSize),
      fontSize: fontSize,
    );
  }

  var size = canvasSize.height;
  for (var i = 0; i < 3; i++) {
    final tp = TextPainter(
      text: TextSpan(text: guide, style: _guideStyle(size, Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    if (tp.width <= 0 || tp.height <= 0) break;
    final scale = math.min(
      canvasSize.width * kGuideFill / tp.width,
      canvasSize.height * kGuideFill / tp.height,
    );
    size *= scale;
    if ((scale - 1).abs() < 0.005) break;
  }
  final tp = TextPainter(
    text: TextSpan(text: guide, style: _guideStyle(size, Colors.white)),
    textDirection: TextDirection.ltr,
  )..layout();
  final left = (canvasSize.width - tp.width) / 2;
  final top = (canvasSize.height - tp.height) / 2;
  return GuideGeometry(
    ink: Rect.fromLTWH(left, top, tp.width, tp.height),
    paintOffset: Offset(left, top),
    fontSize: size,
  );
}

/// Box panduan aksara dalam koordinat kanvas. Fungsi murni agar pengukuran
/// untuk tampilan (painter) dan payload kirim selalu sama.
Rect guideBoxFor(Size canvasSize, String guide) =>
    guideGeometryFor(canvasSize, guide).ink;

class TracingView extends StatefulWidget {
  const TracingView({
    super.key,
    required this.soal,
    required this.onChanged,
    this.benar,
    this.onExpandDone,
    this.onTts,
  });

  final Soal soal;
  final ValueChanged<dynamic> onChanged;

  /// Status penilaian: null = belum diperiksa, true = benar, false = salah.
  final bool? benar;

  /// Dipanggil setelah animasi "mengembang" selesai (atau langsung bila tak ada
  /// yang perlu dianimasikan) agar parent menampilkan kartu hasil.
  final VoidCallback? onExpandDone;
  final VoidCallback? onTts;

  @override
  State<TracingView> createState() => _TracingViewState();
}

class _TracingViewState extends State<TracingView>
    with SingleTickerProviderStateMixin {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  String _status = 'Goresan Aktif';
  Size _canvasSize = const Size(0, 0);

  /// Mencegah penjadwalan setState pasca-frame berulang sebelum viewport
  /// scrollable terukur (frame pertama).
  bool _viewportMeasured = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _expand = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  bool get _locked => widget.benar != null;

  bool get _success => widget.benar == true;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onExpandDone?.call();
    });
    _measureGuide();
  }

  @override
  void didUpdateWidget(covariant TracingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.soal.aksara != widget.soal.aksara) _measureGuide();
    if (widget.benar == true && oldWidget.benar != true) {
      setState(() => _status = 'Berhasil! Aksara Sempurna');
      if (_strokes.isEmpty) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => widget.onExpandDone?.call());
      } else {
        _controller.forward(from: 0);
      }
    } else if (widget.benar == false && oldWidget.benar != false) {
      setState(() => _status = 'Kurang Tepat, Coba Lagi');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ukur metrik raster aksara (sekali per aksara, cache proses) lalu repaint
  /// agar panduan memakai ukuran penuh. Frame pertama masih memakai box layout.
  void _measureGuide() {
    ensureGuideMetrics(widget.soal.aksara).then((updated) {
      if (updated && mounted) setState(() {});
    });
  }

  /// Ruang koordinat ternormalisasi aksara panduan (padanan template web).
  /// Goresan dikirim sebagai [x, y] relatif ke box ini agar sepadan dengan
  /// `kunci_jawaban.paths` di backend.
  Rect _guideBox() => guideBoxFor(_canvasSize, widget.soal.aksara);

  List<List<Offset>> _idealNormalized() {
    final out = <List<Offset>>[];
    for (final stroke in widget.soal.paths) {
      final pts = <Offset>[
        for (final p in stroke) Offset((p['x'] ?? 0).toDouble(), (p['y'] ?? 0).toDouble()),
      ];
      if (pts.isNotEmpty) out.add(pts);
    }
    return out;
  }

  /// Normalisasi goresan mentah ke 0..1 relatif [box] untuk payload saja.
  /// `_strokes` mentah tetap dipakai untuk lukisan. Tiap stroke difilter
  /// (< 2 titik dibuang, duplikat berurutan < 1px dibuang) lalu diresample
  /// ke 64 titik equidistant via interpolasi linear.
  List<List<Offset>> _normalizedStrokes(Rect box) {
    final out = <List<Offset>>[];
    for (final s in _strokes) {
      if (s.length < 2) continue;
      final filtered = <Offset>[s.first];
      for (var i = 1; i < s.length; i++) {
        if ((s[i] - filtered.last).distance >= 1.0) filtered.add(s[i]);
      }
      if (filtered.length < 2) continue;
      final norm = <Offset>[
        for (final p in filtered)
          Offset(
            box.width > 0 ? (p.dx - box.left) / box.width : p.dx,
            box.height > 0 ? (p.dy - box.top) / box.height : p.dy,
          ),
      ];
      out.add(_resample(norm, 64));
    }
    return out;
  }

  /// Resample [pts] ke [n] titik equidistant. Anti-crash untuk input kosong
  /// atau satu titik (tak tercapai karena filter di [_normalizedStrokes]).
  List<Offset> _resample(List<Offset> pts, int n) {
    if (pts.isEmpty) return const [];
    if (pts.length == 1) return List<Offset>.filled(n, pts.first);
    if (n <= 1) return <Offset>[pts.first];
    final cum = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    final total = cum.last;
    if (total <= 0) return List<Offset>.filled(n, pts.first);
    final step = total / (n - 1);
    final out = <Offset>[pts.first];
    var seg = 1;
    for (var i = 1; i < n - 1; i++) {
      final target = step * i;
      while (seg < cum.length - 1 && cum[seg] < target) {
        seg++;
      }
      final segLen = cum[seg] - cum[seg - 1];
      final t = segLen <= 0 ? 0.0 : (target - cum[seg - 1]) / segLen;
      final a = pts[seg - 1];
      final b = pts[seg];
      out.add(Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t));
    }
    out.add(pts.last);
    return out;
  }

  void _push() {
    if (_strokes.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final box = _guideBox();
    if (kDebugMode) debugPrint('[TRACING] box=${box.size} strokes=${_strokes.length} pts=${_strokes.fold<int>(0, (a, s) => a + s.length)} ideal=${widget.soal.paths.length} first=${_strokes.isNotEmpty && _strokes.first.isNotEmpty ? _strokes.first.first : null}');
    final norm = _normalizedStrokes(box);
    widget.onChanged({
      'paths': [
        for (final s in norm)
          [
            for (final p in s) {'x': p.dx, 'y': p.dy},
          ],
      ],
      'strokes': [
        for (final s in norm)
          [
            for (final p in s) [p.dx, p.dy],
          ],
      ],
      'template': [
        for (final s in _idealNormalized())
          [
            for (final p in s) {'x': p.dx, 'y': p.dy},
          ],
      ],
    });
  }

  void _reset() {
    if (_locked) return;
    setState(() {
      _strokes.clear();
      _current = null;
      _status = 'Goresan Aktif';
    });
    _push();
  }

  Future<void> _snap() async {
    if (_locked) return;
    setState(() {
      if (_strokes.isNotEmpty) {
        final last = _strokes.last;
        if (last.length > 2) {
          final smooth = <Offset>[last.first];
          for (var i = 1; i < last.length - 1; i++) {
            smooth.add(Offset(
              (last[i - 1].dx + last[i].dx + last[i + 1].dx) / 3,
              (last[i - 1].dy + last[i].dy + last[i + 1].dy) / 3,
            ));
          }
          smooth.add(last.last);
          _strokes[_strokes.length - 1] = smooth;
        }
      }
      _status = 'Goresan Dirapikan';
    });
    _push();
  }

  @override
  Widget build(BuildContext context) {
    // Layout fixed setinggi viewport. Parent menaruh TracingView di dalam
    // SingleChildScrollView yang ruangnya sudah dibatasi Expanded, jadi
    // SizedBox dibuat pas setinggi ruang tampil — tidak ada sisa scroll dan
    // goresan vertikal tidak lagi menggeser halaman secara tak sengaja.
    //
    // Ukuran diambil dari viewport scrollable asli (angka ground truth):
    // chrome di atas/bawah (header, footer, SafeArea) sudah termasuk di
    // dalamnya dan tidak perlu ditebak — tebakan chrome pernah meleset
    // karena SafeArea mengosongkan padding/viewPadding untuk keturunannya.
    final media = MediaQuery.of(context);
    // Fallback bila tidak ada scrollable ancestor (pemakaian lain):
    // perkiraan kasar dari tinggi layar dikurangi chrome yang diketahui.
    const headerH = 65.0; // KuisHeader 64 + border bawah
    const footerH = 84.0; // tombol Periksa + padding footer parent (overestimate)
    const parentPaddingV = 44.0; // padding vertikal scroll parent (20 + 24)
    double available = (media.size.height -
            media.viewPadding.top -
            headerH -
            footerH -
            parentPaddingV)
        .clamp(350.0, 860.0);

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      final sv = context.findAncestorWidgetOfExactType<SingleChildScrollView>();
      if (sv != null) {
        // viewportDimension null-check crash sebelum layout pertama.
        final extent =
            scrollable.position.hasViewportDimension ? scrollable.position.viewportDimension : 0.0;
        if (extent > 0) {
          // Padding scrollable diterapkan di dalam viewport, jadi ruang anak
          // = viewport − padding vertikal. Clamp menjaga ≤ viewport.
          final padV = (sv.padding ?? EdgeInsets.zero).vertical;
          available = (extent - padV).clamp(350.0, 860.0);
        } else if (!_viewportMeasured) {
          // Frame pertama: viewportDimension belum terisi saat build.
          // Ukur ulang setelah layout pertama supaya tidak tersangkut.
          _viewportMeasured = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _viewportMeasured = false;
            if (mounted) setState(() {});
          });
        }
      }
    }

    return SizedBox(
      height: available,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoCard(),
          const SizedBox(height: 12),
          Expanded(child: _canvasCard()),
        ],
      ),
    );
  }

  /// Ringkasan soal satu baris (aksara, latin, petunjuk) — padatan dari
  /// header lama agar kanvas mengambil sisa ruang maksimal.
  Widget _infoCard() {
    final latin = widget.soal.soalLatin ?? '';
    final sub = [
      if (latin.isNotEmpty) 'Latin: $latin',
      widget.soal.petunjuk,
    ].join('  •  ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.soal.aksara,
              style: AppFonts.javanese(size: 24, color: AppColors.primary700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LATIHAN MENULIS AKSARA (FR-22 TRACING)',
                  style: AppFonts.manrope(
                    size: 11,
                    weight: FontWeight.w800,
                    color: AppColors.primary600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.manrope(size: 12, color: AppColors.gray500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu kanvas: mengisi sisa ruang yang tersedia (Expanded), kanvas
  /// fleksibel mengikuti sisa, tombol aksi tetap terlihat di bawah.
  Widget _canvasCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Symbols.draw, color: AppColors.primary700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kanvas Tracing Aksara', style: AppFonts.epilogue(size: 17, weight: FontWeight.w800)),
                    Text(
                      'Telusuri garis putus-putus mengikuti bentuk aksara',
                      style: AppFonts.manrope(size: 12, color: AppColors.gray500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _status.contains('Berhasil')
                      ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                      : AppColors.primaryFixed.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _status,
                  style: AppFonts.manrope(
                    size: 12,
                    weight: FontWeight.w800,
                    color: _status.contains('Berhasil')
                        ? const Color(0xFF16A34A)
                        : AppColors.primary700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF14352A),
                      border: Border.all(
                        color: AppColors.primary400.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: GestureDetector(
                      onPanStart: (d) {
                        if (_locked) return;
                        setState(() {
                          _current = [d.localPosition];
                          _strokes.add(_current!);
                        });
                      },
                      onPanUpdate: (d) {
                        if (_locked) return;
                        setState(() {
                          _current?.add(d.localPosition);
                        });
                        _push();
                      },
                      onPanEnd: (_) {
                        if (_locked) return;
                        _current = null;
                        _push();
                      },
                      child: AnimatedBuilder(
                        animation: _expand,
                        builder: (context, _) => CustomPaint(
                          painter: _TracingPainter(
                            strokes: _strokes,
                            guide: widget.soal.aksara,
                            t: _expand.value,
                            ideal: _idealNormalized(),
                            success: _success,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _locked ? null : _reset,
                  icon: const Icon(Symbols.refresh, size: 18, color: AppColors.primary600),
                  label: Text('Hapus Goresan', style: AppFonts.manrope(size: 13, weight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.gray200),
                    foregroundColor: AppColors.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _locked ? null : _snap,
                  icon: const Icon(Symbols.auto_fix_high, size: 18),
                  label: Text('Rapikan Goresan', style: AppFonts.manrope(size: 13, weight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryFixed,
                    foregroundColor: AppColors.primary700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Text(
              'Telusuri bentuk aksara nganti ketemu. Yen kurang mirip, kanvas bakal mbaleni otomatis.',
              textAlign: TextAlign.center,
              style: AppFonts.manrope(size: 13, color: AppColors.gray500),
            ),
          ),
        ],
      ),
    );
  }
}

class _TracingPainter extends CustomPainter {
  _TracingPainter({
    required this.strokes,
    required this.guide,
    required this.t,
    required this.ideal,
    required this.success,
  });

  final List<List<Offset>> strokes;
  final String guide;

  /// Progres animasi "mengembang" (0 = goresan asli, 1 = memenuhi panduan).
  final double t;

  /// Goresan ideal ternormalisasi 0..1 (dari Soal.paths); kosong = fallback glif.
  final List<List<Offset>> ideal;

  /// True saat jawaban dinilai benar: crossfade ke bentuk sempurna.
  final bool success;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    GuideGeometry? geom;
    if (guide.isNotEmpty) {
      geom = guideGeometryFor(canvasSize, guide);
      final tp = TextPainter(
        text: TextSpan(
          text: guide,
          style: _guideStyle(
            geom.fontSize,
            Colors.white.withValues(alpha: 0.22),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, geom.paintOffset);
    }
    final guideRect = geom?.ink;

    final userOp = success ? (1.0 - t) : 1.0;
    if (strokes.isNotEmpty && !(success && t >= 1.0)) {
      final guidePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25 * userOp)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final strokePaint = Paint()
        ..color = const Color(0xFFF6D98B).withValues(alpha: 1.0 * userOp)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final strokeBounds = _boundsOf(strokes);
      final transform = _expandTransform(strokeBounds, guideRect, t);

      canvas.save();
      if (transform != null) {
        canvas.translate(transform.center.dx, transform.center.dy);
        canvas.scale(transform.scale);
        canvas.translate(-transform.anchor.dx, -transform.anchor.dy);
      }

      for (final s in strokes) {
        if (s.length < 2) continue;
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (var i = 1; i < s.length; i++) {
          path.lineTo(s[i].dx, s[i].dy);
        }
        canvas.drawPath(path, guidePaint);
        canvas.drawPath(path, strokePaint);
      }

      canvas.restore();
    }

    if (success && t > 0 && guideRect != null) {
      final idealOp = t;
      canvas.save();
      canvas.translate(guideRect.center.dx, guideRect.center.dy);
      canvas.scale(0.7 + 0.3 * t);
      canvas.translate(-guideRect.center.dx, -guideRect.center.dy);
      if (ideal.isNotEmpty) {
        final halo = Paint()
          ..color = Colors.white.withValues(alpha: 0.25 * idealOp)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final core = Paint()
          ..color = const Color(0xFFF6D98B).withValues(alpha: idealOp)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        for (final stroke in ideal) {
          if (stroke.length < 2) continue;
          final path = Path()
            ..moveTo(
              guideRect.left + stroke.first.dx * guideRect.width,
              guideRect.top + stroke.first.dy * guideRect.height,
            );
          for (var i = 1; i < stroke.length; i++) {
            path.lineTo(
              guideRect.left + stroke[i].dx * guideRect.width,
              guideRect.top + stroke[i].dy * guideRect.height,
            );
          }
          canvas.drawPath(path, halo);
          canvas.drawPath(path, core);
        }
      } else if (geom != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: guide,
            style: _guideStyle(
              geom.fontSize,
              const Color(0xFFF6D98B).withValues(alpha: idealOp),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, geom.paintOffset);
      }
      canvas.restore();
    }
  }

  Rect? _boundsOf(List<List<Offset>> strokes) {
    Rect? bounds;
    for (final s in strokes) {
      for (final p in s) {
        final r = Rect.fromCenter(center: p, width: 0, height: 0);
        bounds = bounds == null ? r : bounds.expandToInclude(r);
      }
    }
    return bounds;
  }

  _ExpandTransform? _expandTransform(Rect? strokeBounds, Rect? guideRect, double t) {
    if (strokeBounds == null || guideRect == null) return null;
    if (strokeBounds.width <= 0 || strokeBounds.height <= 0) return null;
    if (guideRect.width <= 0 || guideRect.height <= 0) return null;

    final targetScale = (guideRect.width / strokeBounds.width)
        .clamp(0.0, double.infinity)
        .toDouble();
    final targetScaleH = guideRect.height / strokeBounds.height;
    final fitScale = targetScale < targetScaleH ? targetScale : targetScaleH;

    final anchor = strokeBounds.center;
    final target = guideRect.center;
    return _ExpandTransform(
      scale: _lerp(1.0, fitScale, t),
      anchor: anchor,
      center: Offset(_lerp(anchor.dx, target.dx, t), _lerp(anchor.dy, target.dy, t)),
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.strokes != strokes ||
      oldDelegate.guide != guide ||
      oldDelegate.success != success ||
      oldDelegate.ideal != ideal;
}

class _ExpandTransform {
  const _ExpandTransform({
    required this.scale,
    required this.anchor,
    required this.center,
  });

  final double scale;
  final Offset anchor;
  final Offset center;
}
