import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// State ekspresi wajah maskot kapsul (ala GoPrep PreppyPill).
enum PillMood {
  neutral,
  happy,
  excited,
  thinking,
  speaking,
  sad,
  curious,
}

/// Widget Avatar Maskot Kapsul Interaktif bergaya GoPrep.gg (Preppy AI).
/// Dilengkapi gaze tracking fisika pegas, blinking natural, audio pulse rings,
/// dan real-time lip-sync mulut saat AI berbicara.
class PreppyPillAvatar extends StatefulWidget {
  final PillMood mood;
  final double size; // Lebar kapsul (tinggi = size * 1.32)
  final bool isSpeaking;
  final bool isRecording;
  final double audioLevel; // 0.0 sampai 1.0
  final Offset? touchOffset; // Posisi sentuh relatif terhadap tengah avatar
  final bool showAudioPulse;
  final VoidCallback? onTap;

  const PreppyPillAvatar({
    super.key,
    this.mood = PillMood.neutral,
    this.size = 130.0,
    this.isSpeaking = false,
    this.isRecording = false,
    this.audioLevel = 0.0,
    this.touchOffset,
    this.showAudioPulse = false,
    this.onTap,
  });
  @override
  State<PreppyPillAvatar> createState() => _PreppyPillAvatarState();
}

class _PreppyPillAvatarState extends State<PreppyPillAvatar>
    with TickerProviderStateMixin {
  // Animasi nafas / melayang (idle float)
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Animasi kedip mata (blinking cycle)
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  Timer? _blinkTimer;

  // Animasi gerak mulut (lip-sync)
  late AnimationController _lipSyncController;

  // Animasi denyut gelombang audio (audio pulse rings)
  late AnimationController _pulseController;

  // Gaze tracking interpolator (redaman pegas seperti GoPrep)
  double _currentGazeX = 0.0;
  double _currentGazeY = 0.0;

  @override
  void initState() {
    super.initState();

    // 1. Idle breathing float animation (2.6s)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // 2. Blink animation (160ms)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _startBlinkTimer();

    // 3. Lip-sync animation (140ms per siklus mulut)
    _lipSyncController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    if (widget.isSpeaking || widget.mood == PillMood.speaking) {
      _lipSyncController.repeat(reverse: true);
    }

    // 4. Audio pulse concentric rings (1200ms)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  void _startBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 3600), (_) {
      if (!mounted) return;
      _blinkController.forward().then((_) {
        if (mounted) _blinkController.reverse();
      });
    });
  }

  @override
  void didUpdateWidget(covariant PreppyPillAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final isTalkingNow = widget.isSpeaking || widget.mood == PillMood.speaking;
    final wasTalking = oldWidget.isSpeaking || oldWidget.mood == PillMood.speaking;

    if (isTalkingNow && !wasTalking) {
      _lipSyncController.repeat(reverse: true);
    } else if (!isTalkingNow && wasTalking) {
      _lipSyncController.stop();
      _lipSyncController.reset();
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _floatController.dispose();
    _blinkController.dispose();
    _lipSyncController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.size;
    final height = widget.size * 1.32;

    // Hitung target gaze dari sentuhan pointer
    double targetGazeX = 0.0;
    double targetGazeY = 0.0;

    if (widget.mood == PillMood.thinking) {
      targetGazeX = 10.0;
      targetGazeY = -8.0;
    } else if (widget.touchOffset != null) {
      targetGazeX = (widget.touchOffset!.dx * 0.12).clamp(-14.0, 14.0);
      targetGazeY = (widget.touchOffset!.dy * 0.12).clamp(-9.0, 9.0);
    }

    // Lerp menuju target gaze
    _currentGazeX += (targetGazeX - _currentGazeX) * 0.28;
    _currentGazeY += (targetGazeY - _currentGazeY) * 0.28;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _floatAnimation,
          _blinkAnimation,
          _lipSyncController,
          _pulseController,
        ]),
        builder: (context, child) {
          final floatOffset = _floatAnimation.value;
          final blinkScale = _blinkAnimation.value;
          final lipSyncVal = _lipSyncController.value;
          final pulseVal = _pulseController.value;

          return SizedBox(
            width: width + 80,
            height: height + 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Cincin visualizer gelombang audio konsentris di belakang kapsul
                if (widget.showAudioPulse || widget.isSpeaking || widget.isRecording)
                  CustomPaint(
                    size: Size(width + 70, height + 70),
                    painter: _AudioPulseRingsPainter(
                      progress: pulseVal,
                      audioLevel: widget.audioLevel,
                      color: widget.isRecording
                          ? const Color(0xFFEF4444)
                          : AppColors.primary400,
                    ),
                  ),
                // 2. Kapsul Avatar Si Swara dengan efek mengapung (float)
                Transform.translate(
                  offset: Offset(0, floatOffset),
                child: CustomPaint(
                  size: Size(width, height),
                  painter: _PreppyPillPainter(
                    mood: widget.mood,
                    isSpeaking: widget.isSpeaking || widget.mood == PillMood.speaking,
                    isRecording: widget.isRecording,
                    blinkScale: blinkScale,
                    lipSyncValue: lipSyncVal,
                    audioLevel: widget.audioLevel,
                    gazeX: _currentGazeX,
                    gazeY: _currentGazeY,
                  ),
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }
}

/// CustomPainter untuk menggambar visualizer cincin audio berdenyut.
class _AudioPulseRingsPainter extends CustomPainter {
  final double progress; // 0.0 .. 1.0
  final double audioLevel; // 0.0 .. 1.0
  final Color color;

  _AudioPulseRingsPainter({
    required this.progress,
    required this.audioLevel,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.32;
    final maxExpansion = 28.0 + (audioLevel * 18.0);

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.33)) % 1.0;
      final radius = baseRadius + (ringProgress * maxExpansion);
      final opacity = (1.0 - ringProgress).clamp(0.0, 0.45) * (0.3 + (audioLevel * 0.7));

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 - (ringProgress * 1.2);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioPulseRingsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.audioLevel != audioLevel;
  }
}

/// CustomPainter untuk merender tubuh kapsul PreppyPill dan ekspresi wajah dinamis.
class _PreppyPillPainter extends CustomPainter {
  final PillMood mood;
  final bool isSpeaking;
  final bool isRecording;
  final double blinkScale;
  final double lipSyncValue;
  final double audioLevel;
  final double gazeX;
  final double gazeY;

  _PreppyPillPainter({
    required this.mood,
    required this.isSpeaking,
    this.isRecording = false,
    required this.blinkScale,
    required this.lipSyncValue,
    required this.audioLevel,
    required this.gazeX,
    required this.gazeY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radius = size.width / 2;
    final pillRRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 1. Ambient Drop Shadow kapsul
    final shadowPaint = Paint()
      ..color = AppColors.brand500.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawRRect(pillRRect.shift(const Offset(0, 8)), shadowPaint);

    // 2. Tubuh Kapsul Utama dengan gradient halus
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF3EFFF),
          Color(0xFFE9E2FE),
        ],
      ).createShader(rect);
    canvas.drawRRect(pillRRect, bodyPaint);

    // 3. Border Kapsul Lembut (merah saat merekam seperti versi web)
    final borderPaint = Paint()
      ..color = isRecording
          ? const Color(0xFFEF4444)
          : AppColors.primary400.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isRecording ? 2.8 : 2.2;
    canvas.drawRRect(pillRRect, borderPaint);

    // 4. Aksen Blangkon / Motif Tradisional Jawa di kepala kapsul
    _paintJavaneseHeadBand(canvas, size, radius);

    // 5. Pipi Merona (Blush) pada ekspresi senang / antusias
    if (mood == PillMood.happy || mood == PillMood.excited) {
      _paintBlush(canvas, size);
    }

    // 6. Mata & Alis
    _paintEyes(canvas, size);

    // 7. Mulut (Lip-Sync Real-Time)
    _paintMouth(canvas, size);
  }

  /// Menggambar ikat kepala / aksen blangkon Jawa minimalis di puncak kapsul.
  void _paintJavaneseHeadBand(Canvas canvas, Size size, double radius) {
    final bandPaint = Paint()
      ..color = AppColors.primary700.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.12)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.08,
        size.width * 0.78,
        size.height * 0.12,
      )
      ..lineTo(size.width * 0.75, size.height * 0.16)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.12,
        size.width * 0.25,
        size.height * 0.16,
      )
      ..close();

    canvas.drawPath(path, bandPaint);
  }

  /// Pipi merona (Blush)
  void _paintBlush(Canvas canvas, Size size) {
    final blushPaint = Paint()
      ..color = AppColors.pink500.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Pipi kiri & kanan
    canvas.drawCircle(Offset(size.width * 0.24, size.height * 0.52), 7.5, blushPaint);
    canvas.drawCircle(Offset(size.width * 0.76, size.height * 0.52), 7.5, blushPaint);
  }

  /// Menggambar mata dengan pelacakan gaze (sentuhan) dan kedip (blink).
  void _paintEyes(Canvas canvas, Size size) {
    final eyeY = size.height * 0.44;
    final leftEyeBase = Offset(size.width * 0.35, eyeY);
    final rightEyeBase = Offset(size.width * 0.65, eyeY);

    // Geser titik mata sesuai gaze offset
    final leftEyePos = leftEyeBase + Offset(gazeX, gazeY);
    final rightEyePos = rightEyeBase + Offset(gazeX, gazeY);

    final eyePaint = Paint()
      ..color = AppColors.onSurface
      ..style = PaintingStyle.fill;

    // JIKA SEDANG BERKEDIP
    if (blinkScale < 0.3) {
      final blinkPaint = Paint()
        ..color = AppColors.onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        leftEyeBase + const Offset(-7, 0),
        leftEyeBase + const Offset(7, 0),
        blinkPaint,
      );
      canvas.drawLine(
        rightEyeBase + const Offset(-7, 0),
        rightEyeBase + const Offset(7, 0),
        blinkPaint,
      );
      return;
    }

    // EKSPRESI: HAPPY (Mata melengkung ^^)
    if (mood == PillMood.happy) {
      final happyEyePaint = Paint()
        ..color = AppColors.onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;

      _drawHappyEye(canvas, leftEyeBase, happyEyePaint);
      _drawHappyEye(canvas, rightEyeBase, happyEyePaint);
      return;
    }

    // EKSPRESI: SAD (Mata sayu melengkung ke bawah)
    if (mood == PillMood.sad) {
      final sadEyePaint = Paint()
        ..color = AppColors.onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;

      _drawSadEye(canvas, leftEyeBase, sadEyePaint);
      _drawSadEye(canvas, rightEyeBase, sadEyePaint);
      return;
    }

    // EKSPRESI BIASA / THINKING / EXCITED / SPEAKING (Bola mata oval dengan specular highlight)
    final eyeHeight = 11.5 * blinkScale;
    const eyeWidth = 7.5;

    // Gambar mata kiri & kanan
    canvas.drawOval(
      Rect.fromCenter(center: leftEyePos, width: eyeWidth * 2, height: eyeHeight * 2),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: rightEyePos, width: eyeWidth * 2, height: eyeHeight * 2),
      eyePaint,
    );

    // Titik kilau putih (specular highlight)
    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(leftEyePos + const Offset(-2.2, -2.5), 2.5, highlightPaint);
    canvas.drawCircle(rightEyePos + const Offset(-2.2, -2.5), 2.5, highlightPaint);

    // Jika thinking, gambar alis terangkat
    if (mood == PillMood.thinking || mood == PillMood.curious) {
      final browPaint = Paint()
        ..color = AppColors.onSurface.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      // Alis kiri sedikit mendatar, alis kanan melengkung ke atas
      canvas.drawLine(
        leftEyeBase + const Offset(-8, -14),
        leftEyeBase + const Offset(7, -13),
        browPaint,
      );
      final browPath = Path()
        ..moveTo(rightEyeBase.dx - 7, rightEyeBase.dy - 13)
        ..quadraticBezierTo(
          rightEyeBase.dx,
          rightEyeBase.dy - 19,
          rightEyeBase.dx + 8,
          rightEyeBase.dy - 15,
        );
      canvas.drawPath(browPath, browPaint);
    }
  }

  void _drawHappyEye(Canvas canvas, Offset center, Paint paint) {
    final path = Path()
      ..moveTo(center.dx - 8, center.dy + 2)
      ..quadraticBezierTo(center.dx, center.dy - 8, center.dx + 8, center.dy + 2);
    canvas.drawPath(path, paint);
  }

  void _drawSadEye(Canvas canvas, Offset center, Paint paint) {
    final path = Path()
      ..moveTo(center.dx - 8, center.dy - 3)
      ..quadraticBezierTo(center.dx, center.dy + 3, center.dx + 8, center.dy - 3);
    canvas.drawPath(path, paint);
  }

  /// Menggambar mulut dengan dukungan animasi Lip-Sync real-time.
  void _paintMouth(Canvas canvas, Size size) {
    final mouthCenter = Offset(size.width * 0.5 + (gazeX * 0.3), size.height * 0.58 + (gazeY * 0.2));

    // MODE SPEAKING: Mulut membuka-menutup mengikuti audio & timer lip-sync
    if (isSpeaking) {
      const baseOpenHeight = 4.0;
      final dynamicHeight = baseOpenHeight + (lipSyncValue * 12.0) + (audioLevel * 8.0);
      final mouthWidth = 14.0 + (lipSyncValue * 6.0);

      final mouthRect = Rect.fromCenter(
        center: mouthCenter,
        width: mouthWidth,
        height: dynamicHeight,
      );

      // Lubang mulut gelap
      final mouthBgPaint = Paint()
        ..color = const Color(0xFF2D1B4E)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(mouthRect, const Radius.circular(8)), mouthBgPaint);

      // Lidah pink di dasar mulut
      if (dynamicHeight > 8.0) {
        final tonguePaint = Paint()
          ..color = AppColors.pink500
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          mouthCenter + Offset(0, dynamicHeight * 0.28),
          mouthWidth * 0.32,
          tonguePaint,
        );
      }
      return;
    }

    // MODE HAPPY / EXCITED: Senyum terbuka lebar
    if (mood == PillMood.happy || mood == PillMood.excited) {
      final mouthPath = Path()
        ..moveTo(mouthCenter.dx - 9, mouthCenter.dy - 2)
        ..quadraticBezierTo(mouthCenter.dx, mouthCenter.dy + 11, mouthCenter.dx + 9, mouthCenter.dy - 2)
        ..close();

      final smilePaint = Paint()
        ..color = const Color(0xFF2D1B4E)
        ..style = PaintingStyle.fill;
      canvas.drawPath(mouthPath, smilePaint);

      // Lidah pink
      final tonguePaint = Paint()
        ..color = AppColors.pink500
        ..style = PaintingStyle.fill;
      canvas.drawCircle(mouthCenter + const Offset(0, 4.5), 4.0, tonguePaint);
      return;
    }

    // MODE SAD: Garis melengkung ke bawah
    if (mood == PillMood.sad) {
      final sadPath = Path()
        ..moveTo(mouthCenter.dx - 8, mouthCenter.dy + 4)
        ..quadraticBezierTo(mouthCenter.dx, mouthCenter.dy - 3, mouthCenter.dx + 8, mouthCenter.dy + 4);

      final linePaint = Paint()
        ..color = AppColors.onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(sadPath, linePaint);
      return;
    }

    // MODE THINKING: Mulut "o" kecil atau senyum tipis miring
    if (mood == PillMood.thinking || mood == PillMood.curious) {
      final linePaint = Paint()
        ..color = AppColors.onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      final smirkPath = Path()
        ..moveTo(mouthCenter.dx - 6, mouthCenter.dy + 2)
        ..quadraticBezierTo(mouthCenter.dx, mouthCenter.dy + 3, mouthCenter.dx + 7, mouthCenter.dy - 1);
      canvas.drawPath(smirkPath, linePaint);
      return;
    }

    // MODE DEFAULT / NEUTRAL: Senyum melengkung lembut
    final neutralPath = Path()
      ..moveTo(mouthCenter.dx - 8, mouthCenter.dy - 1)
      ..quadraticBezierTo(mouthCenter.dx, mouthCenter.dy + 6, mouthCenter.dx + 8, mouthCenter.dy - 1);

    final linePaint = Paint()
      ..color = AppColors.onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(neutralPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PreppyPillPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.isRecording != isRecording ||
        oldDelegate.blinkScale != blinkScale ||
        oldDelegate.lipSyncValue != lipSyncValue ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.gazeX != gazeX ||
        oldDelegate.gazeY != gazeY;
  }
}
