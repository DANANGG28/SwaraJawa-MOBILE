import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../models/quiz_result.dart';
import '../../../models/soal.dart';
import '../../../state/app_state.dart';

class KuisSuaraView extends StatefulWidget {
  const KuisSuaraView({
    super.key,
    required this.soal,
    required this.onResult,
  });

  final Soal soal;
  final ValueChanged<KuisSuaraResult> onResult;

  @override
  State<KuisSuaraView> createState() => _KuisSuaraViewState();
}

class _KuisSuaraViewState extends State<KuisSuaraView> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  int _seconds = 0;
  bool _recording = false;
  bool _processing = false;
  bool _ttsLoading = false;
  KuisSuaraResult? _result;

  @override
  void initState() {
    super.initState();
    _result = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playTts() async {
    setState(() => _ttsLoading = true);
    try {
      final res = await context.read<AppState>().speech.tts(widget.soal.teksReferensi);
      final url = AppConfig.resolveUrl(res.audioUrl);
      if (url.isNotEmpty) {
        await _player.play(UrlSource(url));
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal memutar audio contoh.');
    } finally {
      if (mounted) setState(() => _ttsLoading = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_processing) return;
    if (_recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  RecordConfig _recordConfig() => kIsWeb
      ? const RecordConfig(encoder: AudioEncoder.opus)
      : const RecordConfig(encoder: AudioEncoder.aacLc);

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _snack('Izin mikrofon ditolak. Gunakan "Coba Mode Demo".');
        return;
      }
      final path = kIsWeb
          ? 'rekaman_${DateTime.now().millisecondsSinceEpoch}.webm'
          : '${(await getTemporaryDirectory()).path}/rekaman_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(_recordConfig(), path: path);
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _seconds = (_seconds + 1).clamp(0, 10));
        if (_seconds >= 10) _stopRecording();
      });
    } catch (_) {
      _snack('Mikrofon tidak tersedia. Gunakan "Coba Mode Demo".');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    setState(() {
      _recording = false;
      _processing = true;
    });
    if (path == null) {
      setState(() => _processing = false);
      return;
    }
    await _kirim(path, demo: false);
  }

  Future<void> _kirim(String path, {required bool demo}) async {
    setState(() => _processing = true);
    try {
      final res = await context.read<AppState>().speech.quizSuara(
            widget.soal.id,
            audioPath: path,
            demo: demo,
          );
      setState(() => _result = res);
      widget.onResult(res);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal memproses audio, coba lagi.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _demo() async {
    await _kirim('', demo: true);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.soal.pertanyaan,
          textAlign: TextAlign.center,
          style: AppFonts.epilogue(size: 19, weight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
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
              Container(
                height: 4,
                width: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '“${widget.soal.teksReferensi}”',
                textAlign: TextAlign.center,
                style: AppFonts.epilogue(size: 21, weight: FontWeight.w800, color: AppColors.primary700),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _ttsLoading ? null : _playTts,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_ttsLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Symbols.volume_up, size: 18, color: AppColors.primary700),
                      const SizedBox(width: 8),
                      Text(
                        _ttsLoading ? 'Nyetel Swara...' : 'Dengarkan Contoh (edge-tts)',
                        style: AppFonts.manrope(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.primary700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _micSection(),
        const SizedBox(height: 12),
        if (_result != null) _resultCard(_result!),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.gray200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _processing ? null : _demo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.play_circle, size: 20, color: AppColors.onSurface),
                      const SizedBox(width: 8),
                      Text('Coba Mode Demo', style: AppFonts.manrope(size: 14, weight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  'Pipeline: STT → Fuzzy Matching → edge-tts',
                  textAlign: TextAlign.right,
                  style: AppFonts.manrope(size: 11, color: AppColors.gray400),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _micSection() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
            if (_recording)
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.primary400.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _recording ? AppColors.error : AppColors.primary600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary600.withValues(alpha: 0.28),
                      offset: const Offset(0, 10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(
                  _recording ? Symbols.stop : Symbols.mic,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_recording)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Nyemak swara panjenengan...',
                style: AppFonts.manrope(size: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '00:${_seconds.toString().padLeft(2, '0')} / 00:10',
                  style: AppFonts.manrope(
                    size: 12,
                    weight: FontWeight.w800,
                    color: AppColors.primary700,
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            _processing ? 'Memproses suara...' : 'Ketuk untuk Mulai Rekam Ucapan',
            style: AppFonts.manrope(size: 13, color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _resultCard(KuisSuaraResult res) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: res.benar ? const Color(0xFF22C55E) : AppColors.error,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HASIL SUARA',
            style: AppFonts.manrope(
              size: 11,
              weight: FontWeight.w800,
              color: AppColors.gray500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            res.transkripsi.isEmpty ? 'Durung ana rekaman.' : '“${res.transkripsi}”',
            style: AppFonts.manrope(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Skor: ${res.skor}/100',
            style: AppFonts.epilogue(
              size: 15,
              weight: FontWeight.w800,
              color: res.benar ? const Color(0xFF16A34A) : AppColors.error,
            ),
          ),
          if (res.teksRespons != null && res.teksRespons!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              res.teksRespons!,
              style: AppFonts.manrope(size: 13, color: AppColors.onSurfaceVariant),
            ),
          ],
          if (res.mock) ...[
            const SizedBox(height: 6),
            Text(
              '(Mode mock — layanan AI belum dikonfigurasi)',
              style: AppFonts.manrope(size: 11, color: AppColors.gray500),
            ),
          ],
        ],
      ),
    );
  }
}
