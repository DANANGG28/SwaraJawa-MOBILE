import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/quiz_result.dart';
import '../../models/soal.dart';
import '../../state/app_state.dart';

class LatihanNgomongScreen extends StatefulWidget {
  const LatihanNgomongScreen({super.key});

  @override
  State<LatihanNgomongScreen> createState() => _LatihanNgomongScreenState();
}

class _LatihanNgomongScreenState extends State<LatihanNgomongScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  Soal? _soal;
  bool _loading = true;
  String? _error;

  bool _recording = false;
  bool _processing = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  LatihanNgomongResult? _result;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      final levels = await state.materi.daftarMateri();
      Soal? found;
      for (final level in levels) {
        if (level.terkunci) continue;
        final detail = await state.materi.detail(level.id);
        final match = detail.soal.where((s) => s.tipeSoal == Soal.tipeKuisSuara);
        if (match.isNotEmpty) {
          found = match.first;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _soal = found;
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

  Future<void> _playContoh() async {
    final soal = _soal;
    if (soal == null) return;
    try {
      final res = await context.read<AppState>().speech.tts(soal.teksReferensi);
      final url = AppConfig.resolveUrl(res.audioUrl);
      if (url.isNotEmpty) await _player.play(UrlSource(url));
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal memutar audio contoh.');
    }
  }

  Future<void> _toggleMic() async {
    if (_processing) return;
    if (_recording) {
      await _stop();
    } else {
      await _start();
    }
  }

  RecordConfig _recordConfig() => kIsWeb
      ? const RecordConfig(encoder: AudioEncoder.opus)
      : const RecordConfig(encoder: AudioEncoder.aacLc);

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        _snack('Mikrofon tidak tersedia. Gunakan "Coba mode demo".');
        return;
      }
      final path = kIsWeb
          ? 'ngomong_${DateTime.now().millisecondsSinceEpoch}.webm'
          : '${(await getTemporaryDirectory()).path}/ngomong_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(_recordConfig(), path: path);
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _elapsed += const Duration(seconds: 1));
        if (_elapsed.inSeconds >= 15) _stop();
      });
    } catch (_) {
      _snack('Mikrofon tidak tersedia. Gunakan "Coba mode demo".');
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    setState(() {
      _recording = false;
      _processing = true;
    });
    if (path != null) await _kirim(path, demo: false);
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _kirim(String path, {required bool demo}) async {
    final soal = _soal;
    if (soal == null) return;
    try {
      final res = await context.read<AppState>().speech.latihanNgomong(
            soal.id,
            audioPath: path,
            demo: demo,
          );
      if (!mounted) return;
      setState(() => _result = res);
      final url = AppConfig.resolveUrl(res.audioUrl);
      if (url.isNotEmpty) {
        await _player.play(UrlSource(url));
        setState(() => _playing = true);
        _player.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = false);
        });
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal memproses audio.');
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _elapsed = Duration.zero;
      _playing = false;
    });
    _player.stop();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(child: _body()),
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
        border: Border(bottom: BorderSide(color: AppColors.gray100)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
            child: const Icon(Symbols.close, size: 20, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 14,
                color: AppColors.surfaceContainerHighest,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _result != null ? 1.0 : (_recording ? 0.5 : 0.4),
                    child: Container(color: AppColors.green500),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _result != null ? '1/1' : '0/1',
            style: AppFonts.manrope(size: 12, weight: FontWeight.w700, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary600));
    }
    final soal = _soal;
    if (_error != null || soal == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gray200, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.record_voice_over, size: 48, color: AppColors.gray500),
                const SizedBox(height: 12),
                Text(
                  'Belum ana soal latihan ngomong',
                  style: AppFonts.epilogue(size: 20, weight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rampungna level sadurunge utawa hubungi guru kanggo nambah soal.',
                  textAlign: TextAlign.center,
                  style: AppFonts.manrope(size: 14, color: AppColors.gray500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary600,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _ttsCard(soal),
          const SizedBox(height: 18),
          _micSection(),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _guruAiCard(_result!),
          ],
          const SizedBox(height: 18),
          _actions(),
        ],
      ),
    );
  }

  Widget _ttsCard(Soal soal) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gray100),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E1E2A), offset: Offset(0, 8), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _playContoh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.volume_up, size: 18, color: AppColors.primary700),
                  const SizedBox(width: 6),
                  Text(
                    'Dengarkan Audio',
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
          const SizedBox(height: 14),
          Text(
            '“${soal.teksReferensi}”',
            style: AppFonts.epilogue(size: 22, weight: FontWeight.w700, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _micSection() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (_recording)
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.primary400.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
            GestureDetector(
              onTap: _toggleMic,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _recording ? AppColors.error : AppColors.primary600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary700.withValues(alpha: 0.24),
                      offset: const Offset(0, 14),
                      blurRadius: 28,
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
        const SizedBox(height: 12),
        Text(
          _recording
              ? 'Nyimak pengucapanmu... ketuk maneh kanggo mungkasi'
              : (_processing ? 'Ngolah swara panjenengan...' : 'Ketuk untuk Mulai Rekam Ucapan'),
          textAlign: TextAlign.center,
          style: AppFonts.epilogue(size: 15, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _waveform(),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _kirim('', demo: true),
          child: Text(
            'Mic ora kasedhiya? Coba mode demo',
            style: AppFonts.manrope(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.gray500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _waveform() {
    final heights = [8.0, 14.0, 22.0, 28.0, 18.0, 12.0, 8.0];
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final h in heights)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 4,
                height: _recording ? h * (_elapsed.inMilliseconds % 2 == 0 ? 1 : 0.6) : h * 0.5,
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _guruAiCard(LatihanNgomongResult res) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gray100),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E1E2A), offset: Offset(0, 8), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.primary700, AppColors.primary500]),
                ),
                alignment: Alignment.center,
                child: const Icon(Symbols.smart_toy, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Guru AI', style: AppFonts.epilogue(size: 17, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    if (_playing) {
                      await _player.stop();
                      setState(() => _playing = false);
                    } else {
                      final url = AppConfig.resolveUrl(res.audioUrl);
                      if (url.isNotEmpty) {
                        await _player.play(UrlSource(url));
                        setState(() => _playing = true);
                      }
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _playing ? Symbols.pause : Symbols.play_arrow,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dengarkan Koreksi Guru AI',
                    style: AppFonts.manrope(size: 12, color: AppColors.gray500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HASIL SUARAMU',
                  style: AppFonts.manrope(
                    size: 11,
                    weight: FontWeight.w800,
                    color: AppColors.gray500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  res.transkripsi.isEmpty ? 'Durung ana rekaman.' : '“${res.transkripsi}”',
                  style: AppFonts.manrope(size: 15, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            res.feedbackText ?? '',
            style: AppFonts.manrope(size: 15, height: 1.5),
          ),
          if (res.mock) ...[
            const SizedBox(height: 6),
            Text(
              '(Mode mock — layanan AI belum dikonfigurasi)',
              style: AppFonts.manrope(size: 12, color: AppColors.gray500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        GestureDetector(
          onTap: _reset,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Symbols.replay, size: 18),
                const SizedBox(width: 8),
                Text('Coba Ulangi', style: AppFonts.epilogue(size: 15, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.primary600,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary700.withValues(alpha: 0.22),
                  offset: const Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              children: [
                Text('Rampung', style: AppFonts.epilogue(size: 15, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(width: 8),
                const Icon(Symbols.arrow_forward, size: 18, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
