import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../models/soal.dart';

TextStyle _guideStyle(
  double fontSize,
  Color color, {
  FontWeight weight = FontWeight.w700,
}) {
  try {
    return GoogleFonts.notoSansJavanese(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
    );
  } catch (_) {
    return AppFonts.javanese(size: fontSize, weight: weight, color: color);
  }
}

/// Geometri dan objek TextPainter panduan aksara yang di-cache agar rendering 60-120fps mulus.
class GuideRenderCache {
  const GuideRenderCache({
    required this.ink,
    required this.paintOffset,
    required this.fontSize,
    required this.widthStretch,
    required this.heightStretch,
    required this.sketchFillPainter,
    required this.sketchStrokePainter,
    required this.solidBlockPainter,
  });

  final Rect ink;
  final Offset paintOffset;
  final double fontSize;
  final double widthStretch;
  final double heightStretch;

  /// Sketsa panduan awal sebelum selesai menggambar
  final TextPainter sketchFillPainter;

  /// Garis putih outline tebal pada frame sketsa yang SELALU BERTAHAN membingkai aksara
  final TextPainter sketchStrokePainter;

  /// Blok warna penuh aksara dengan warna hijau yang sama dengan garis user (#34D399)
  final TextPainter solidBlockPainter;
}

/// Menghitung geometri aksara agar SELALU berada tepat di tengah-tengah kanvas (center-aligned),
/// dengan jalur yang TEBAL, LEBAR KE SAMPING (~34%) dan LEBAR/TINGGI KE ATAS (~30%),
/// sehingga lekukan dan puncak aksara sangat tinggi, lapang, dan mudah ditelusuri oleh jari.
GuideRenderCache? buildGuideRenderCache(Size canvasSize, String guide) {
  if (guide.isEmpty || canvasSize.width <= 0 || canvasSize.height <= 0) {
    return null;
  }

  // 1. Ukur dimensi acuan untuk menghitung rasio lebar & baseline dengan bobot font tebal (w700)
  const refSize = 100.0;
  final refTp = TextPainter(
    text: TextSpan(
      text: guide,
      style: _guideStyle(refSize, Colors.white, weight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();

  final refW = refTp.width > 0 ? refTp.width : (refSize * 0.85);
  final lmList = refTp.computeLineMetrics();
  final refBaseline = lmList.isNotEmpty ? lmList.first.baseline : (refSize * 1.15);

  const visualHeightRatio = 0.60;
  final visualWidthRatio = (refW / refSize).clamp(0.40, 2.20);

  // Melebarkan aksara secara horizontal (~34%) dan vertikal/menjulang ke atas (~30%)
  const widthStretch = 1.34;
  const heightStretch = 1.30;

  // 2. Skala ukuran font lebih besar dan tinggi ke atas (mengisi kanvas dengan proporsi lapang)
  final scaleW = (canvasSize.width * 0.94) / (visualWidthRatio * widthStretch);
  final scaleH = (canvasSize.height * 0.90) / (visualHeightRatio * heightStretch);
  final fontSize = math.min(scaleW, scaleH).clamp(52.0, 480.0);

  // 3. Hitung posisi tepat di tengah kanvas
  final cx = canvasSize.width / 2;
  final cy = canvasSize.height / 2;

  final baseline = fontSize * (refBaseline / refSize);
  final paintX = cx - (refW * (fontSize / refSize) / 2);

  // Titik pusat visual vertikal konsonan aksara Jawa
  final visualCenterInBox = baseline - (fontSize * 0.28);
  final paintY = cy - visualCenterInBox;

  final inkW = fontSize * visualWidthRatio * widthStretch;
  final inkH = fontSize * visualHeightRatio * heightStretch;
  final inkRect = Rect.fromCenter(
    center: Offset(cx, cy),
    width: inkW,
    height: inkH,
  );
  final paintOffset = Offset(paintX, paintY);

  // 4. Fill lembut awal sketsa (area badan aksara lebih jelas terlihat jalurnya)
  final sketchFill = TextPainter(
    text: TextSpan(
      text: guide,
      style: _guideStyle(
        fontSize,
        Colors.white.withValues(alpha: 0.20),
        weight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();

  // 5. Garis putih elegan dan rapi (2.0px) frame sketsa membingkai jalur aksara dengan bersih
  final sketchStroke = TextPainter(
    text: TextSpan(
      text: guide,
      style: _guideStyle(
        fontSize,
        Colors.white,
        weight: FontWeight.w700,
      ).copyWith(
        foreground: Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 // Garis outline lebih tipis dan rapi
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();

  // 6. Blok penuh warna hijau aksara — warna SAMA PERSIS dengan garis user: #34D399 (Emerald)
  final solidBlock = TextPainter(
    text: TextSpan(
      text: guide,
      style: _guideStyle(
        fontSize,
        const Color(0xFF34D399),
        weight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();

  return GuideRenderCache(
    ink: inkRect,
    paintOffset: paintOffset,
    fontSize: fontSize,
    widthStretch: widthStretch,
    heightStretch: heightStretch,
    sketchFillPainter: sketchFill,
    sketchStrokePainter: sketchStroke,
    solidBlockPainter: solidBlock,
  );
}

/// Algoritma penipisan Zhang-Suen untuk mengekstrak skeleton 1-piksel aksara
/// menyamai implementasi Web (aksara-tracing-canvas.js).
List<int> _thinZhangSuen(List<bool> img, int w, int h) {
  final copy = List<int>.generate(w * h, (i) => img[i] ? 1 : 0);
  int at(int x, int y) => copy[y * w + x];
  var changed = true;

  while (changed) {
    changed = false;
    for (var step = 0; step < 2; step++) {
      final del = <int>[];
      for (var y = 1; y < h - 1; y++) {
        for (var x = 1; x < w - 1; x++) {
          final i = y * w + x;
          if (copy[i] == 0) continue;
          final p2 = at(x, y - 1);
          final p3 = at(x + 1, y - 1);
          final p4 = at(x + 1, y);
          final p5 = at(x + 1, y + 1);
          final p6 = at(x, y + 1);
          final p7 = at(x - 1, y + 1);
          final p8 = at(x - 1, y);
          final p9 = at(x - 1, y - 1);
          final b = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9;
          if (b < 2 || b > 6) continue;
          final seq = [p2, p3, p4, p5, p6, p7, p8, p9, p2];
          var a = 0;
          for (var k = 0; k < 8; k++) {
            if (seq[k] == 0 && seq[k + 1] == 1) a++;
          }
          if (a != 1) continue;
          if (step == 0) {
            if (p2 * p4 * p6 != 0) continue;
            if (p4 * p6 * p8 != 0) continue;
          } else {
            if (p2 * p4 * p8 != 0) continue;
            if (p2 * p6 * p8 != 0) continue;
          }
          del.add(i);
        }
      }
      if (del.isNotEmpty) {
        for (final i in del) {
          copy[i] = 0;
        }
        changed = true;
      }
    }
  }
  return copy;
}

List<Offset> _normalizeToBounds(List<Offset> pts) {
  if (pts.length < 2) return pts;
  var minX = pts[0].dx;
  var maxX = pts[0].dx;
  var minY = pts[0].dy;
  var maxY = pts[0].dy;
  for (final p in pts) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  final w = math.max(1e-4, maxX - minX);
  final h = math.max(1e-4, maxY - minY);
  return [for (final p in pts) Offset((p.dx - minX) / w, (p.dy - minY) / h)];
}

double _meanNearestDistance(List<Offset> src, List<Offset> target) {
  if (src.isEmpty || target.isEmpty) return 0.0;
  var sum = 0.0;
  for (final p in src) {
    var best = double.infinity;
    for (final q in target) {
      final dx = p.dx - q.dx;
      final dy = p.dy - q.dy;
      final d = dx * dx + dy * dy;
      if (d < best) best = d;
    }
    sum += math.sqrt(best);
  }
  return sum / src.length;
}

/// Menghitung skor kemiripan goresan dengan template acuan ($1 Unistroke / traceCoverage)
/// persis menyamai algoritma di Web (aksara-tracing-canvas.js & DollarRecognizer::traceCoverage).
double _calculateTraceCoverage(
  List<List<Offset>> candidateStrokes,
  List<List<Offset>> templateStrokes, {
  double tolerance = 0.35,
}) {
  final candidate = <Offset>[];
  for (final s in candidateStrokes) {
    candidate.addAll(s);
  }
  final template = <Offset>[];
  for (final s in templateStrokes) {
    template.addAll(s);
  }
  if (candidate.length < 2 || template.length < 2) return 0.0;

  final normCandidate = _normalizeToBounds(candidate);
  final normTemplate = _normalizeToBounds(template);

  final avg = (_meanNearestDistance(normCandidate, normTemplate) +
          _meanNearestDistance(normTemplate, normCandidate)) /
      2.0;

  return (1.0 - (avg / math.max(1e-6, tolerance))).clamp(0.0, 1.0);
}

/// Masker hit-test berbasis raster dari bentuk aksara (Noto Sans Javanese).
/// Memungkinkan deteksi akurat apakah goresan menyentuh jalur aksara atau
/// mencorat-coret di ruang kosong / luar template aksara.
class _GlyphHitMask {
  const _GlyphHitMask({
    required this.width,
    required this.height,
    required this.scale,
    required this.grid,
    this.templateStrokes = const [],
  });

  final int width;
  final int height;
  final double scale;
  final List<bool> grid;
  final List<List<Offset>> templateStrokes;

  bool isHit(double x, double y) {
    final ix = (x * scale).round();
    final iy = (y * scale).round();
    if (ix < 0 || ix >= width || iy < 0 || iy >= height) return false;
    return grid[iy * width + ix];
  }
}

Future<_GlyphHitMask?> _buildGlyphMask(
  Size size,
  GuideRenderCache cache,
) async {
  try {
    const targetDim = 120.0;
    final maxDim = math.max(size.width, size.height);
    if (maxDim <= 0) return null;
    final scale = targetDim / maxDim;
    final w = (size.width * scale).round().clamp(40, 200);
    final h = (size.height * scale).round().clamp(40, 200);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);

    canvas.save();
    canvas.translate(cache.ink.center.dx, cache.ink.center.dy);
    canvas.scale(cache.widthStretch, cache.heightStretch);
    canvas.translate(-cache.ink.center.dx, -cache.ink.center.dy);

    cache.solidBlockPainter.paint(canvas, cache.paintOffset);
    cache.sketchStrokePainter.paint(canvas, cache.paintOffset);
    canvas.restore();

    final pic = recorder.endRecording();
    final img = await pic.toImage(w, h);
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return null;

    final bytes = bd.buffer.asUint8List();
    final raw = List<bool>.filled(w * h, false);
    for (var i = 0; i < w * h; i++) {
      if (bytes[i * 4 + 3] > 20) {
        raw[i] = true;
      }
    }

    // Ekstraksi garis skeleton 1-piksel untuk template acuan penilaian (menyulap font menjadi vektor)
    final thinned = _thinZhangSuen(raw, w, h);
    final skeletonPts = <Offset>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (thinned[y * w + x] != 0) {
          skeletonPts.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
    final templateStrokes = <List<Offset>>[];
    if (skeletonPts.length >= 2) {
      templateStrokes.add(_normalizeToBounds(skeletonPts));
    }

    // Dilasi jari: radius 4 (~16-20px pada kanvas) memberi koridor sentuh yang wajar
    final dilated = List<bool>.filled(w * h, false);
    const radius = 4;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (raw[y * w + x]) {
          for (var dy = -radius; dy <= radius; dy++) {
            final ny = y + dy;
            if (ny < 0 || ny >= h) continue;
            for (var dx = -radius; dx <= radius; dx++) {
              final nx = x + dx;
              if (nx < 0 || nx >= w) continue;
              if (dx * dx + dy * dy <= radius * radius) {
                dilated[ny * w + nx] = true;
              }
            }
          }
        }
      }
    }

    return _GlyphHitMask(
      width: w,
      height: h,
      scale: scale,
      grid: dilated,
      templateStrokes: templateStrokes,
    );
  } catch (e) {
    debugPrint('[TracingView] Gagal buildGlyphMask: $e');
    return null;
  }
}

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

  /// Dipanggil setelah animasi selesai agar parent menampilkan modal/kartu hasil.
  final VoidCallback? onExpandDone;
  final VoidCallback? onTts;

  @override
  State<TracingView> createState() => _TracingViewState();
}

class _TracingViewState extends State<TracingView>
    with TickerProviderStateMixin {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  Size _canvasSize = const Size(0, 0);

  GuideRenderCache? _guideCache;
  _GlyphHitMask? _glyphMask;
  bool _viewportMeasured = false;
  bool _fontReady = false;
  Timer? _stopDrawTimer;
  Timer? _retryTimer;
  String? _statusMessage;
  bool _statusIsError = false;

  /// Ambang batas akurasi frame aksara (70%).
  static const double kPassThreshold = 70.0;

  /// Jeda sebelum goresan otomatis dihapus jika keluar bingkai (< 70%).
  static const Duration kRetryDelay = Duration(milliseconds: 800);

  /// Toleransi jarak sentuhan jari di sekitar area batas bingkai aksara.
  static const double kFramePadding = 24.0;

  // Animasi saat jawaban dinilai benar
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _expand = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  // Animasi transisi saat warna aksara mulai menjadi full hijau
  late final AnimationController _fillController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _fillAnimation = CurvedAnimation(
    parent: _fillController,
    curve: Curves.easeInOut,
  );

  bool get _locked => widget.benar != null;
  bool get _success => widget.benar == true;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onExpandDone?.call();
    });
    _ensureFontLoaded();
  }

  /// Memastikan font Noto Sans Javanese selesai diunduh & dimuat ke engine Flutter.
  /// Setelah font terpasang, re-layout TextPainter agar bentuk aksara asli tampil
  /// sempurna dan TIDAK menghasilkan kotak-kotak (tofu).
  void _ensureFontLoaded() {
    AppFonts.preloadJavanese().then((_) {
      if (!mounted) return;
      setState(() {
        _fontReady = true;
        if (_canvasSize.width > 0 && _canvasSize.height > 0) {
          _guideCache = buildGuideRenderCache(_canvasSize, widget.soal.aksara);
          _updateMask();
        }
      });
    }).catchError((_) {
      if (mounted) setState(() => _fontReady = true);
    });
  }

  void _updateMask() {
    final cache = _guideCache;
    final size = _canvasSize;
    if (cache == null || size.width <= 0 || size.height <= 0) return;
    _buildGlyphMask(size, cache).then((mask) {
      if (mounted && mask != null) {
        _glyphMask = mask;
      }
    });
  }

  @override
  void didUpdateWidget(covariant TracingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.soal.aksara != oldWidget.soal.aksara) {
      _stopDrawTimer?.cancel();
      _retryTimer?.cancel();
      _fillController.reset();
      _guideCache = buildGuideRenderCache(_canvasSize, widget.soal.aksara);
      _glyphMask = null;
      _updateMask();
      _strokes.clear();
      _current = null;
      _statusMessage = null;
      _statusIsError = false;
    }

    if (widget.benar == true && oldWidget.benar != true) {
      _fillController.forward();
      if (_strokes.isEmpty) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => widget.onExpandDone?.call());
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _stopDrawTimer?.cancel();
    _retryTimer?.cancel();
    _controller.dispose();
    _fillController.dispose();
    super.dispose();
  }

  void _updateCanvasSize(Size size) {
    if (_canvasSize != size && size.width > 0 && size.height > 0) {
      _canvasSize = size;
      _guideCache = buildGuideRenderCache(_canvasSize, widget.soal.aksara);
      _updateMask();
    }
  }

  Rect _guideBox() {
    return _guideCache?.ink ??
        Rect.fromCenter(
          center: Offset(_canvasSize.width / 2, _canvasSize.height / 2),
          width: _canvasSize.width * 0.94,
          height: _canvasSize.height * 0.88,
        );
  }

  List<List<Offset>> _idealNormalized() {
    final out = <List<Offset>>[];
    for (final stroke in widget.soal.paths) {
      final pts = <Offset>[
        for (final p in stroke)
          Offset((p['x'] ?? 0).toDouble(), (p['y'] ?? 0).toDouble()),
      ];
      if (pts.isNotEmpty) out.add(pts);
    }
    if (out.isNotEmpty) return out;

    // Fallback template dari skeleton Noto Sans Javanese jika DB soal belum memiliki paths
    final maskTpl = _glyphMask?.templateStrokes;
    if (maskTpl != null && maskTpl.isNotEmpty) {
      return maskTpl;
    }

    return out;
  }

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

  /// Dikirim ke parent HANYA saat selesai satu goresan (onPanEnd) atau saat reset.
  void _push() {
    if (_strokes.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final box = _guideBox();
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

  /// Menghitung persentase kemiripan goresan terhadap bentuk aksara (0..100%).
  /// Menggabungkan hit-test raster masker aksara (agar coretan di luar aksara ditolak)
  /// dan algoritma $1 Unistroke / traceCoverage menyamai Web & DollarRecognizer di server.
  double _evaluateFrameAccuracy() {
    if (_strokes.isEmpty) return 0.0;

    var insideCount = 0;
    var totalCount = 0;
    final mask = _glyphMask;

    if (mask != null) {
      for (final stroke in _strokes) {
        for (final pt in stroke) {
          totalCount++;
          if (mask.isHit(pt.dx, pt.dy)) {
            insideCount++;
          }
        }
      }
    }

    final maskRatio = totalCount > 0 ? (insideCount / totalCount) : 0.0;

    // Jika dominan corak-coret di luar jalur aksara (< 65% titik kena aksara), langsung gagal
    if (mask != null && maskRatio < 0.65) {
      return maskRatio * 100.0;
    }

    final idealStrokes = _idealNormalized();
    if (idealStrokes.isNotEmpty) {
      final normStrokes = _normalizedStrokes(_guideBox());
      final coverage = _calculateTraceCoverage(normStrokes, idealStrokes);
      final coveragePercent = coverage * 100.0;
      if (mask != null) {
        return math.min(maskRatio * 100.0, coveragePercent);
      }
      return coveragePercent;
    }

    if (totalCount == 0) return 0.0;
    return maskRatio * 100.0;
  }

  int _totalStrokePoints() {
    var count = 0;
    for (final s in _strokes) {
      count += s.length;
    }
    return count;
  }

  void _reset() {
    if (_locked) return;
    _stopDrawTimer?.cancel();
    _retryTimer?.cancel();
    _fillController.reset();
    setState(() {
      _strokes.clear();
      _current = null;
      _statusMessage = null;
      _statusIsError = false;
    });
    _push();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_locked) return;
    _stopDrawTimer?.cancel();
    _retryTimer?.cancel();
    if (_fillController.value > 0) {
      _fillController.reset();
    }
    setState(() {
      _current = [event.localPosition];
      _strokes.add(_current!);
      if (_statusIsError) {
        _statusMessage = null;
        _statusIsError = false;
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_locked) return;
    if (_current == null) {
      setState(() {
        _current = [event.localPosition];
        _strokes.add(_current!);
      });
      return;
    }
    setState(() {
      _current!.add(event.localPosition);
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_locked) return;
    _current = null;
    _handleStrokeEnd();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_locked) return;
    _current = null;
    _handleStrokeEnd();
  }

  void _handleStrokeEnd() {
    if (_locked) return;

    final totalPts = _totalStrokePoints();
    if (totalPts < 5) {
      _push();
      return;
    }

    final accuracy = _evaluateFrameAccuracy();

    if (accuracy < kPassThreshold) {
      _stopDrawTimer?.cancel();
      _retryTimer?.cancel();

      setState(() {
        _statusIsError = true;
        _statusMessage = 'Belum sesuai (${accuracy.toInt()}%)';
      });

      // Kosongkan jawaban agar tombol kirim nonaktif
      widget.onChanged(null);

      _retryTimer = Timer(kRetryDelay, () {
        if (!mounted || _locked) return;
        _reset();
      });
    } else {
      _retryTimer?.cancel();
      setState(() {
        _statusIsError = false;
        _statusMessage = 'Aksara tepat! (${accuracy.toInt()}%)';
      });

      _push();

      // Saat user selesai menggambar: otomatis isi full warna hijau (#34D399)
      _stopDrawTimer?.cancel();
      _stopDrawTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted && _strokes.isNotEmpty) {
          _fillController.forward();
        }
      });

      Timer(const Duration(milliseconds: 1500), () {
        if (mounted && !_statusIsError && _statusMessage != null) {
          setState(() => _statusMessage = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const headerH = 65.0;
    const footerH = 84.0;
    const parentPaddingV = 44.0;
    double available = (media.size.height -
            media.viewPadding.top -
            headerH -
            footerH -
            parentPaddingV)
        .clamp(480.0, 920.0);

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      final sv = context.findAncestorWidgetOfExactType<SingleChildScrollView>();
      if (sv != null) {
        final extent = scrollable.position.hasViewportDimension
            ? scrollable.position.viewportDimension
            : 0.0;
        if (extent > 0) {
          final padV = (sv.padding ?? EdgeInsets.zero).vertical;
          available = (extent - padV).clamp(480.0, 920.0);
        } else if (!_viewportMeasured) {
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
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoCard(),
              const SizedBox(height: 10),
              Expanded(child: _canvasCard()),
            ],
          ),
          if (_statusMessage != null)
            Positioned(
              top: 56,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _statusIsError
                        ? const Color(0xCCDC2626)
                        : const Color(0xCC059669),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.70),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIsError ? Symbols.warning : Symbols.check_circle,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusMessage!,
                        style: AppFonts.manrope(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Header petunjuk & audio (warna disesuaikan dengan AppColors.primary proyek).
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
        border: Border.all(color: AppColors.gray200),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary600.withValues(alpha: 0.25),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.soal.aksara,
              style: AppFonts.javanese(size: 24, color: AppColors.primary700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TELUSURI AKSARA',
                  style: AppFonts.epilogue(
                    size: 11,
                    weight: FontWeight.w800,
                    color: AppColors.primary600, // Warna primary proyek
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.manrope(size: 12, color: AppColors.gray500),
                ),
              ],
            ),
          ),
          if (widget.onTts != null) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTts,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary600.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.volume_up,
                        size: 16,
                        color: AppColors.primary600, // Warna primary proyek
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bunyi',
                        style: AppFonts.manrope(
                          size: 12,
                          weight: FontWeight.w700,
                          color: AppColors.primary700, // Warna primary proyek
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Kartu Kanvas Tracing (Bersih dan Luas).
  Widget _canvasCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray200),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                _updateCanvasSize(size);

                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF14352A), // Latar kanvas chalkboard tetap hijau
                      border: Border.all(
                        color: _statusIsError
                            ? const Color(0xFFEF4444).withValues(alpha: 0.70)
                            : const Color(0xFF10B981).withValues(alpha: 0.35),
                        width: _statusIsError ? 2.0 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: RawGestureDetector(
                      gestures: {
                        EagerGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                          (instance) {},
                        ),
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerUp,
                        onPointerCancel: _onPointerCancel,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: Listenable.merge([_expand, _fillAnimation]),
                              builder: (context, _) => CustomPaint(
                                painter: _TracingPainter(
                                  strokes: _strokes,
                                guideCache: _guideCache,
                                guide: widget.soal.aksara,
                                fillProgress: _fillAnimation.value,
                                t: _expand.value,
                                success: _success,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          if (!_fontReady && _guideCache == null)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.8,
                                      color: Color(0xFF34D399),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nyiyapake aksara...',
                                    style: AppFonts.manrope(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _locked ? null : _reset,
            icon: const Icon(Symbols.refresh, size: 18, color: AppColors.primary600),
            label: Text(
              'Hapus Ulang',
              style: AppFonts.manrope(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.gray200),
              foregroundColor: AppColors.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
    required this.guideCache,
    required this.guide,
    required this.fillProgress,
    required this.t,
    required this.success,
  });

  final List<List<Offset>> strokes;
  final GuideRenderCache? guideCache;
  final String guide;

  /// Progres blok warna penuh aksara (0 = sketsa panduan, 1 = blok penuh hijau #34D399)
  final double fillProgress;

  /// Progres animasi sukses (0 = normal, 1 = selesai dinilai benar)
  final double t;

  /// True saat jawaban dinilai benar.
  final bool success;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // 0. Grid papan tulis (32px step) menyamai kanvas Web (aksara-tracing-canvas.js)
    final gridPaint = Paint()
      ..color = const Color(0x0FFFFFFF) // rgba(255, 255, 255, 0.06)
      ..strokeWidth = 1.0;
    const step = 32.0;
    for (var x = step; x < canvasSize.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, canvasSize.height), gridPaint);
    }
    for (var y = step; y < canvasSize.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(canvasSize.width, y), gridPaint);
    }

    if (guideCache != null) {
      canvas.save();
      // Melebarkan bentuk aksara secara horizontal & vertikal ke atas dari titik tengah kanvas
      canvas.translate(guideCache!.ink.center.dx, guideCache!.ink.center.dy);
      canvas.scale(guideCache!.widthStretch, guideCache!.heightStretch);
      canvas.translate(-guideCache!.ink.center.dx, -guideCache!.ink.center.dy);

      // 1. Sketsa fill panduan awal lembut (badan aksara jelas terlihat jalurnya)
      if (fillProgress < 1.0) {
        guideCache!.sketchFillPainter.paint(canvas, guideCache!.paintOffset);
      }

      // 2. Blok bentuk aksara penuh dengan warna hijau yang sama dengan garis user (#34D399)
      if (fillProgress > 0.0) {
        if (fillProgress >= 1.0) {
          guideCache!.solidBlockPainter.paint(canvas, guideCache!.paintOffset);
        } else {
          final bounds = guideCache!.ink.inflate(40);
          canvas.saveLayer(
            bounds,
            Paint()..color = Colors.white.withValues(alpha: fillProgress),
          );
          guideCache!.solidBlockPainter.paint(canvas, guideCache!.paintOffset);
          canvas.restore();
        }
      }

      canvas.restore();
    }

    // 3. Goresan Siswa (Tebal & empuk 5.5px sesuai lebar jalur sketsa, tanpa garis hitam)
    if (strokes.isNotEmpty) {
      final strokePaint = Paint()
        ..color = const Color(0xFF34D399)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final dotPaint = Paint()
        ..color = const Color(0xFF34D399)
        ..style = PaintingStyle.fill;

      for (final s in strokes) {
        if (s.isEmpty) continue;
        if (s.length == 1) {
          canvas.drawCircle(s.first, strokePaint.strokeWidth / 2, dotPaint);
          continue;
        }
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (var i = 1; i < s.length; i++) {
          path.lineTo(s[i].dx, s[i].dy);
        }
        canvas.drawPath(path, strokePaint);
      }
    }

    // 4. GARIS PUTIH FRAME SKETSA TETAP BERTAHAN (Tebal 3.8px membingkai jalur aksara)
    if (guideCache != null) {
      canvas.save();
      canvas.translate(guideCache!.ink.center.dx, guideCache!.ink.center.dy);
      canvas.scale(guideCache!.widthStretch, guideCache!.heightStretch);
      canvas.translate(-guideCache!.ink.center.dx, -guideCache!.ink.center.dy);

      guideCache!.sketchStrokePainter.paint(canvas, guideCache!.paintOffset);

      canvas.restore();
    }

    // 5. Efek Transisi Sukses Sempurna
    if (success && t > 0 && guideCache != null) {
      final idealOp = t;
      canvas.save();
      canvas.translate(guideCache!.ink.center.dx, guideCache!.ink.center.dy);
      canvas.scale(
        guideCache!.widthStretch * (0.96 + 0.04 * t),
        guideCache!.heightStretch * (0.96 + 0.04 * t),
      );
      canvas.translate(-guideCache!.ink.center.dx, -guideCache!.ink.center.dy);

      final glowPainter = TextPainter(
        text: TextSpan(
          text: guide,
          style: _guideStyle(
            guideCache!.fontSize,
            const Color(0xFF34D399).withValues(alpha: idealOp),
            weight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      glowPainter.paint(canvas, guideCache!.paintOffset);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) => true;
}
