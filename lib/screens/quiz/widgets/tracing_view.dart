import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../models/soal.dart';

class TracingView extends StatefulWidget {
  const TracingView({
    super.key,
    required this.soal,
    required this.onChanged,
    this.onTts,
  });

  final Soal soal;
  final ValueChanged<dynamic> onChanged;
  final VoidCallback? onTts;

  @override
  State<TracingView> createState() => _TracingViewState();
}

class _TracingViewState extends State<TracingView> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  String _status = 'Goresan Aktif';

  void _push() {
    if (_strokes.isEmpty) {
      widget.onChanged(null);
    } else {
      widget.onChanged({
        'strokes': [
          for (final s in _strokes) [for (final p in s) {'x': p.dx, 'y': p.dy}],
        ],
        'template': const [],
      });
    }
  }

  void _reset() {
    setState(() {
      _strokes.clear();
      _current = null;
      _status = 'Goresan Aktif';
    });
    _push();
  }

  Future<void> _snap() async {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
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
                'LATIHAN MENULIS AKSARA (FR-22 TRACING)',
                style: AppFonts.manrope(
                  size: 11,
                  weight: FontWeight.w800,
                  color: AppColors.primary600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Telusuri bentuk aksara dengan menggambar pada kanvas!',
                style: AppFonts.epilogue(size: 20, weight: FontWeight.w800, height: 1.25),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: AppFonts.manrope(size: 12, color: AppColors.gray500),
                  children: [
                    const TextSpan(text: 'Aksara: '),
                    TextSpan(
                      text: widget.soal.aksara,
                      style: AppFonts.javanese(size: 18, color: AppColors.onSurface),
                    ),
                    if (widget.soal.soalLatin != null && widget.soal.soalLatin!.isNotEmpty) ...[
                      const TextSpan(text: '  •  Latin: '),
                      TextSpan(
                        text: widget.soal.soalLatin,
                        style: AppFonts.manrope(
                          size: 12,
                          weight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                    TextSpan(text: '  •  ${widget.soal.petunjuk}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
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
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  const height = 440.0;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: width,
                      height: height,
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
                          setState(() {
                            _current = [d.localPosition];
                            _strokes.add(_current!);
                          });
                        },
                        onPanUpdate: (d) {
                          setState(() {
                            _current?.add(d.localPosition);
                          });
                          _push();
                        },
                        onPanEnd: (_) {
                          _current = null;
                          _push();
                        },
                        child: CustomPaint(
                          painter: _TracingPainter(
                            strokes: _strokes,
                            guide: widget.soal.aksara,
                            size: Size(width, height),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
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
                      onPressed: _snap,
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
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray100),
                ),
                child: Text(
                  'Telusuri bentuk aksara nganti ketemu. Yen kurang mirip, kanvas bakal mbaleni otomatis.',
                  textAlign: TextAlign.center,
                  style: AppFonts.manrope(size: 14, color: AppColors.gray500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TracingPainter extends CustomPainter {
  _TracingPainter({required this.strokes, required this.guide, required this.size});

  final List<List<Offset>> strokes;
  final String guide;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (guide.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: guide,
          style: TextStyle(
            fontSize: canvasSize.height * 0.6,
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (canvasSize.width - tp.width) / 2,
          (canvasSize.height - tp.height) / 2,
        ),
      );
    }

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strokePaint = Paint()
      ..color = const Color(0xFFF6D98B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final s in strokes) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (var i = 1; i < s.length; i++) {
        path.lineTo(s[i].dx, s[i].dy);
      }
      canvas.drawPath(path, guidePaint);
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) => true;
}
