import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../core/audio/tts_playback.dart';
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
      final ok = await TtsPlayback.playTts(_player, res);
      if (!ok) {
        _snack('Gagal memutar audio contoh.');
      } else if (res.mock) {
        _snack('Audio contoh dalam mode mock (mesin TTS backend belum aktif).');
      }
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
      final ok = await TtsPlayback.playUrl(_player, res.audioUrl);
      if (ok) {
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
        child: Stack(
          children: [
            Column(
              children: [
                _header(),
                Expanded(child: _body()),
              ],
            ),
            if (_result != null) _modalOverlay(_result!),
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
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
              child: const Icon(Symbols.close, size: 20, color: AppColors.onSurfaceVariant),
            ),
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
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gray200),
              boxShadow: const [
                BoxShadow(color: Color(0x0F000000), offset: Offset(0, 4), blurRadius: 12),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Symbols.record_voice_over, size: 36, color: AppColors.primary600),
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada soal latihan',
                  textAlign: TextAlign.center,
                  style: AppFonts.epilogue(size: 20, weight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rampungna level sadurunge utawa hubungi guru kanggo nambah soal.',
                  textAlign: TextAlign.center,
                  style: AppFonts.manrope(size: 13, color: AppColors.gray500),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary600,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary600.withValues(alpha: 0.25),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      'Bali menyang Beranda',
                      style: AppFonts.manrope(size: 13, weight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Main Container Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gray200),
              boxShadow: const [
                BoxShadow(color: Color(0x0D000000), offset: Offset(0, 4), blurRadius: 12),
              ],
            ),
            child: Column(
              children: [
                // Header Badge & Instruction
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Symbols.record_voice_over, size: 16, color: AppColors.primary700),
                          const SizedBox(width: 6),
                          Text(
                            'LATIHAN WICARA BASA JAWA',
                            style: AppFonts.manrope(
                              size: 11,
                              weight: FontWeight.w800,
                              color: AppColors.primary700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ucapkan Kalimat di Bawah Ini:',
                      textAlign: TextAlign.center,
                      style: AppFonts.epilogue(
                        size: 18,
                        weight: FontWeight.w800,
                        color: AppColors.black900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.gray100),
                const SizedBox(height: 16),
                // Sentence / TTS Card
                _ttsCard(soal),
                const SizedBox(height: 20),
                // Recording Control Area
                _micSection(),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.gray100),
                const SizedBox(height: 12),
                // Footer action in main card
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Kembali ke Beranda',
                            style: AppFonts.epilogue(size: 12, weight: FontWeight.w700, color: AppColors.black900),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Symbols.arrow_forward, size: 16, color: AppColors.black900),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ttsCard(Soal soal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(
        children: [
          Text(
            '“${soal.teksReferensi}”',
            textAlign: TextAlign.center,
            style: AppFonts.epilogue(
              size: 22,
              weight: FontWeight.w800,
              color: AppColors.primary700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _playContoh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), offset: Offset(0, 2), blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.volume_up, size: 18, color: AppColors.primary700),
                  const SizedBox(width: 8),
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.primary400.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            GestureDetector(
              onTap: _toggleMic,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _recording ? AppColors.error : AppColors.primary600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_recording ? AppColors.error : AppColors.primary600).withValues(alpha: 0.35),
                      offset: const Offset(0, 10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(
                  _recording ? Symbols.stop : Symbols.mic,
                  size: 34,
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
        const SizedBox(height: 8),
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
    final bars = [
      (8.0, AppColors.primary400),
      (12.0, AppColors.primary500),
      (20.0, AppColors.primary600),
      (26.0, AppColors.primary700),
      (20.0, AppColors.primary600),
      (14.0, AppColors.primary500),
      (8.0, AppColors.primary400),
    ];
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < bars.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 5,
                height: _recording ? bars[i].$1 * ((_elapsed.inMilliseconds + i * 150) % 2 == 0 ? 1.0 : 0.4) : bars[i].$1 * 0.4,
                decoration: BoxDecoration(
                  color: bars[i].$2,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modalOverlay(LatihanNgomongResult res) {
    return Positioned.fill(
      child: Material(
        color: const Color(0x990F172A), // Slate-900 / 60% backdrop
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: _reset,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () {}, // Prevent tap through dismiss
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.gray100),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), offset: Offset(0, 12), blurRadius: 32),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modal Header
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary600,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(color: Color(0x1A000000), offset: Offset(0, 2), blurRadius: 4),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Symbols.smart_toy, size: 22, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Umpan Balik Guru AI',
                                  style: AppFonts.epilogue(size: 16, weight: FontWeight.w800, color: AppColors.black900),
                                ),
                                Text(
                                  'Hasil Evaluasi Pengucapan',
                                  style: AppFonts.manrope(size: 11, weight: FontWeight.w600, color: AppColors.primary600),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _reset,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Symbols.close, size: 18, color: AppColors.gray500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Hasil Suaramu
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gray100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Symbols.hearing, size: 16, color: AppColors.gray500),
                                const SizedBox(width: 6),
                                Text(
                                  'HASIL SUARAMU',
                                  style: AppFonts.manrope(
                                    size: 11,
                                    weight: FontWeight.w800,
                                    color: AppColors.gray500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              res.transkripsi.isEmpty ? 'Durung ana rekaman.' : '“${res.transkripsi}”',
                              style: AppFonts.manrope(size: 15, weight: FontWeight.w700, color: AppColors.black900),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Audio Koreksi Guru AI
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gray100),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                if (_playing) {
                                  await _player.stop();
                                  setState(() => _playing = false);
                                } else {
                                  final ok = await TtsPlayback.playUrl(_player, res.audioUrl);
                                  if (ok) {
                                    setState(() => _playing = true);
                                    _player.onPlayerComplete.listen((_) {
                                      if (mounted) setState(() => _playing = false);
                                    });
                                  }
                                }
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary600,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary600.withValues(alpha: 0.3),
                                      offset: const Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _playing ? Symbols.pause : Symbols.play_arrow,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: _playing ? null : 0.0,
                                      backgroundColor: AppColors.gray200,
                                      color: AppColors.primary600,
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Dengarkan Koreksi Guru AI',
                                    style: AppFonts.manrope(size: 11, weight: FontWeight.w600, color: AppColors.gray500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Feedback Text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gray100),
                          boxShadow: const [
                            BoxShadow(color: Color(0x0A000000), offset: Offset(0, 2), blurRadius: 4),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CATATAN EVALUASI:',
                              style: AppFonts.manrope(
                                size: 10,
                                weight: FontWeight.w800,
                                color: AppColors.gray500,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              res.feedbackText ?? '',
                              style: AppFonts.manrope(size: 13, height: 1.5, color: AppColors.black900),
                            ),
                            if (res.mock) ...[
                              const SizedBox(height: 6),
                              Text(
                                '(Mode mock — layanan AI belum dikonfigurasi)',
                                style: AppFonts.manrope(size: 11, color: AppColors.gray500),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Actions: Coba Ulangi & Rampung
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _reset,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.gray200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Symbols.replay, size: 18, color: AppColors.gray500),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Coba Ulangi',
                                      style: AppFonts.epilogue(size: 13, weight: FontWeight.w700, color: AppColors.black900),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).maybePop(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary600,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary600.withValues(alpha: 0.25),
                                      offset: const Offset(0, 4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Rampung',
                                      style: AppFonts.epilogue(size: 13, weight: FontWeight.w700, color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Symbols.arrow_forward, size: 18, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
