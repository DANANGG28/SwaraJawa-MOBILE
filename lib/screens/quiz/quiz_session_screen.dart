import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/bagian.dart';
import '../../models/level_materi.dart';
import '../../models/quiz_result.dart';
import '../../models/soal.dart';
import '../../services/materi_service.dart';
import '../../services/speech_service.dart';
import '../../state/app_state.dart';
import 'widgets/feedback_modal.dart';
import 'widgets/kuis_chrome.dart';
import 'widgets/kuis_suara_view.dart';
import 'widgets/pilihan_ganda_view.dart';
import 'widgets/susun_view.dart';
import 'widgets/tracing_view.dart';

class QuizSessionScreen extends StatefulWidget {
  const QuizSessionScreen({super.key, required this.level, this.bagian});

  final LevelMateri level;
  final Bagian? bagian;

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  MateriDetail? _detail;
  bool _loading = true;
  String? _error;
  int _index = 0;
  dynamic _jawaban;
  JawabanResult? _result;
  bool _submitting = false;
  bool _muted = false;
  final AudioPlayer _ttsPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _load(bagianId: widget.bagian?.id);
  }

  @override
  void dispose() {
    _ttsPlayer.dispose();
    super.dispose();
  }

  Future<void> _load({int? bagianId, bool widenFallback = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      var detail = await state.materi.mulaiSesi(widget.level.id, bagianId: bagianId);

      // Bila bagian yang dipilih sudah tuntas, soal belum selesai bisa berada
      // di bagian lain pada unit yang sama -> muat scope unit penuh.
      if (widenFallback &&
          detail.firstUnfinishedSoalId != null &&
          !detail.soal.any((s) => s.id == detail.firstUnfinishedSoalId)) {
        detail = await state.materi.mulaiSesi(widget.level.id);
      }

      if (!mounted) return;
      setState(() {
        _detail = detail;
        _index = _indexOfSoal(detail.soal, detail.firstUnfinishedSoalId);
        _jawaban = null;
        _result = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat soal.';
        _loading = false;
      });
    }
  }

  /// Posisi soal pertama yang belum selesai; fallback ke soal pertama.
  int _indexOfSoal(List<Soal> list, int? soalId) {
    if (soalId == null) return 0;
    final i = list.indexWhere((s) => s.id == soalId);
    return i >= 0 ? i : 0;
  }

  Soal? get _soal {
    final list = _detail?.soal ?? const [];
    if (_index < 0 || _index >= list.length) return null;
    return list[_index];
  }

  void _click() {
    if (!_muted) SystemSound.play(SystemSoundType.click);
  }

  Future<void> _submit() async {
    final soal = _soal;
    if (soal == null || _jawaban == null || _submitting) return;
    _click();
    setState(() => _submitting = true);
    try {
      final res = await context.read<AppState>().kuis.jawab(
            soalId: soal.id,
            jawaban: _jawaban,
          );
      if (!mounted) return;
      setState(() => _result = res);
      _showFeedback(FeedbackModalData.fromResult(res));
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal mengirim jawaban.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showFeedback(FeedbackModalData data) {
    showQuizFeedbackModal(
      context,
      data: data,
      onNext: () {
        Navigator.of(context).pop();
        _next();
      },
      onHome: () {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _next() async {
    final list = _detail?.soal ?? const <Soal>[];

    // Navigasi berbasis server (setelah menjawab) — menyamai alur website.
    if (_result != null) {
      final nextId = _result!.nextSoalId;
      if (nextId != null) {
        final idx = list.indexWhere((s) => s.id == nextId);
        if (idx >= 0) {
          setState(() {
            _index = idx;
            _jawaban = null;
            _result = null;
          });
          return;
        }
        // Soal berikutnya berada di bagian lain -> muat scope baru lalu lompat.
        await _load(bagianId: _result!.nextPembahasanId, widenFallback: false);
        if (!mounted) return;
        final i2 = (_detail?.soal ?? const <Soal>[]).indexWhere((s) => s.id == nextId);
        if (i2 >= 0) setState(() => _index = i2);
        return;
      }
      // Tidak ada soal lanjutan -> seluruh unit tuntas.
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Belum dijawab (lompati): maju sekuensial.
    if (_index < list.length - 1) {
      setState(() {
        _index++;
        _jawaban = null;
        _result = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skip() {
    _click();
    _next();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final soal = _soal;
    final total = _detail?.soal.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            KuisHeader(
              nomor: total == 0 ? 0 : _index + 1,
              total: total,
              muted: _muted,
              onClose: () => Navigator.of(context).pop(),
              onToggleSound: () {
                setState(() => _muted = !_muted);
                if (!_muted) _click();
              },
            ),
            Expanded(child: _body(soal)),
            if (soal != null && soal.tipeEfektif != Soal.tipeKuisSuara) _footer(soal),
          ],
        ),
      ),
    );
  }

  Widget _body(Soal? soal) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary600));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.lock, size: 48, color: AppColors.gray400),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppFonts.manrope(size: 15, color: AppColors.gray500),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary600),
                child: const Text('Bali menyang Beranda'),
              ),
            ],
          ),
        ),
      );
    }
    if (soal == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: KuisEmptyCard(
            icon: Symbols.quiz,
            title: 'Belum ana soal',
            message:
                'Rampungna level sadurunge utawa hubungi guru kanggo nambah soal.',
          ),
        ),
      );
    }

    final total = _detail?.soal.length ?? 0;
    final key = ValueKey('soal-${soal.id}');
    switch (soal.tipeEfektif) {
      case Soal.tipeSusunKalimat:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: SusunView(
            key: key,
            soal: soal,
            result: _result,
            onChanged: (j) => setState(() => _jawaban = j),
            onTts: () => _playTts(soal),
          ),
        );
      case Soal.tipePuzzle:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: SusunView(
            key: key,
            soal: soal,
            result: _result,
            puzzle: true,
            onChanged: (j) => setState(() => _jawaban = j),
          ),
        );
      case Soal.tipeMenulisAksara:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: TracingView(
            key: key,
            soal: soal,
            onChanged: (j) => setState(() => _jawaban = j),
          ),
        );
      case Soal.tipeKuisSuara:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: KuisSuaraView(
            key: key,
            soal: soal,
            onResult: (res) {
              _showFeedback(FeedbackModalData(
                benar: res.benar,
                skor: res.skor,
                expDidapat: res.expDidapat,
                currentStreak: res.currentStreak,
                title: res.benar ? 'Lancar & Bener!' : 'Belum Tepat',
                kunciDisplay: soal.teksReferensi,
                keterangan: res.transkripsi.isNotEmpty
                    ? 'Terdeteksi: “${res.transkripsi}”'
                    : null,
                levelSelesai: res.levelSelesai,
                rewardExp: res.rewardExp,
                levelBerikutnya: res.levelBerikutnya,
              ));
            },
          ),
        );
      default:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: PilihanGandaView(
            key: key,
            soal: soal,
            nomor: _index + 1,
            total: total,
            result: _result,
            onChanged: (j) => setState(() => _jawaban = j),
          ),
        );
    }
  }

  Widget _footer(Soal soal) {
    final isSusun =
        soal.tipeEfektif == Soal.tipeSusunKalimat || soal.tipeEfektif == Soal.tipePuzzle;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.gray200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (isSusun) ...[
            GestureDetector(
              onTap: _skip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'LOMPATI',
                  style: AppFonts.epilogue(
                    size: 14,
                    weight: FontWeight.w800,
                    color: AppColors.gray500,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            const Spacer(),
            PeriksaButton(
              enabled: _jawaban != null && _result == null,
              loading: _submitting,
              label: 'Periksa',
              onTap: _submit,
            ),
          ] else
            Expanded(
              child: PeriksaButton(
                enabled: _jawaban != null && _result == null,
                loading: _submitting,
                label: soal.tipeEfektif == Soal.tipeMenulisAksara
                    ? 'Periksa & Kirim Jawaban'
                    : 'Periksa Jawaban',
                onTap: _submit,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _playTts(Soal soal) async {
    try {
      final SpeechService speech = context.read<AppState>().speech;
      final res = await speech.tts(soal.pertanyaan);
      final url = AppConfig.resolveUrl(res.audioUrl);
      if (url.isEmpty) return;
      await _ttsPlayer.stop();
      await _ttsPlayer.play(UrlSource(url));
    } catch (_) {
      // Audio hanya pambantu — abaikan galat.
    }
  }
}
