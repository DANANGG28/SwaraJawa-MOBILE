import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../core/audio/tts_playback.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/voice_tutor.dart';
import '../../state/app_state.dart';
import '../../widgets/preppy_pill_avatar.dart';

class ChatTurn {
  final bool isUser;
  final String text;
  final String? audioBase64;
  final String? audioUrl;
  final String? suggestedRepeat;
  final List<VoiceTutorVocabulary> vocabulary;

  ChatTurn({
    required this.isUser,
    required this.text,
    this.audioBase64,
    this.audioUrl,
    this.suggestedRepeat,
    this.vocabulary = const [],
  });
}

class LatihanNgomongScreen extends StatefulWidget {
  const LatihanNgomongScreen({super.key});

  @override
  State<LatihanNgomongScreen> createState() => _LatihanNgomongScreenState();
}

class _LatihanNgomongScreenState extends State<LatihanNgomongScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _textController = TextEditingController();

  // Riwayat percakapan & kosakata
  final List<ChatTurn> _history = [];
  final List<VoiceTutorVocabulary> _accumulatedVocab = [];

  // Status perekaman & AI
  bool _recording = false;
  bool _processing = false;
  bool _aiSpeaking = false;
  bool _isHolding = false;
  DateTime? _pressStartTime;
  double _audioLevel = 0.0;
  StreamSubscription<Amplitude>? _amplitudeSub;

  // Subtitle AI saat ini (seperti wadah subtitle di web)
  String? _currentAiSubtitle;
  Map<String, String?> _lastSpokenAudio = {'base64': null, 'url': null};

  // Tantangan pengulangan lafal terkini
  String? _activeRepeatChallenge;

  // Mood & tatapan maskot Si Swara
  PillMood _mascotMood = PillMood.happy;
  Offset? _touchOffset;

  // Pengaturan interaksi
  bool _handsFree = false; // Mode pencet & tahan adalah interaksi utama
  double _playbackSpeed = 1.0;
  DateTime _lastSpeechTime = DateTime.now();

  // Mode alternatif ketik teks
  bool _showTextInput = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _loadInitialGreeting();
  }

  void _initAudioPlayer() {
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _aiSpeaking = false;
        _audioLevel = 0.0;
        _mascotMood = PillMood.happy;
      });

      // Jika mode hands-free aktif, otomatis dengarkan respon siswa setelah AI selesai bicara
      if (_handsFree && !_recording && !_processing && !_isHolding) {
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted && !_aiSpeaking && !_recording && !_isHolding) {
            _startRecording();
          }
        });
      }
    });
  }

  void _loadInitialGreeting() {
    const greetingText =
        'Sugeng rawuh! Kula Si Swara, kanca sinau panjenengan. Mangga wicara Basa Jawa utawa takon apa wae!';
    const repeatTarget = 'Sugeng enjang, Mas Swara';
    final initialVocab = [
      const VoiceTutorVocabulary(
        word: 'Sugeng rawuh',
        meaning: 'Selamat datang',
        level: 'Krama',
      ),
      const VoiceTutorVocabulary(
        word: 'Kanca',
        meaning: 'Teman / Kawan',
        level: 'Ngoko',
      ),
    ];

    _history.add(ChatTurn(
      isUser: false,
      text: greetingText,
      suggestedRepeat: repeatTarget,
      vocabulary: initialVocab,
    ));

    _currentAiSubtitle = greetingText;
    _activeRepeatChallenge = repeatTarget;
    _accumulatedVocab.addAll(initialVocab);
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _textController.dispose();
    super.dispose();
  }

  RecordConfig _recordConfig() => kIsWeb
      ? const RecordConfig(encoder: AudioEncoder.opus)
      : const RecordConfig(encoder: AudioEncoder.aacLc);

  // 1. Interaksi Pencet & Tahan Animasi untuk Merekam
  Future<void> _handlePointerDown() async {
    if (_processing) return;

    // Jika AI sedang berbicara, potong audio agar user bisa langsung berbicara
    if (_aiSpeaking) {
      await _player.stop();
      if (!mounted) return;
      setState(() {
        _aiSpeaking = false;
      });
    }

    _isHolding = true;
    _pressStartTime = DateTime.now();
    HapticFeedback.heavyImpact();

    // Sesuai versi website: saat tombol mic/animasi ditekan, subtitle sebelumnya langsung menghilang
    setState(() {
      _currentAiSubtitle = null;
    });

    await _startRecording();
  }

  Future<void> _handlePointerUp() async {
    if (!_isHolding) return;
    _isHolding = false;

    final pressDuration = _pressStartTime != null
        ? DateTime.now().difference(_pressStartTime!)
        : Duration.zero;

    // Jika durasi terlalu singkat (< 400ms), batalkan dan beri tahu user untuk menahan
    if (pressDuration.inMilliseconds < 400) {
      await _abortRecording(showHint: true);
    } else {
      await _stopRecordingAndSend();
    }
  }

  Future<void> _handlePointerCancel() async {
    if (!_isHolding) return;
    _isHolding = false;
    await _abortRecording(showHint: false);
  }

  Future<void> _abortRecording({bool showHint = false}) async {
    _amplitudeSub?.cancel();
    if (_recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _audioLevel = 0.0;
      _mascotMood = PillMood.happy;
    });
    if (showHint) {
      _snack('Pencet lan tahan Si Swara nalika wicara.');
    }
  }

  Future<void> _startRecording() async {
    if (_processing || _recording) return;

    try {
      if (!await _recorder.hasPermission()) {
        _snack('Izin mikrofon dibutuhake kanggo wicara.');
        _isHolding = false;
        return;
      }

      await _player.stop();

      final path = kIsWeb
          ? 'tutor_${DateTime.now().millisecondsSinceEpoch}.webm'
          : '${(await getTemporaryDirectory()).path}/tutor_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(_recordConfig(), path: path);

      // Pastikan user belum melepas pointer sebelum recorder mulai
      if (!_isHolding && !_handsFree) {
        try {
          await _recorder.stop();
        } catch (_) {}
        return;
      }

      if (!mounted) return;
      setState(() {
        _recording = true;
        _mascotMood = PillMood.neutral;
        _lastSpeechTime = DateTime.now();
      });

      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (!mounted) return;
        final currentDb = amp.current;
        final normalized = ((currentDb + 45.0) / 45.0).clamp(0.0, 1.0);

        setState(() => _audioLevel = normalized);

        if (currentDb > -36.0) {
          _lastSpeechTime = DateTime.now();
        } else if (_handsFree &&
            !_isHolding &&
            DateTime.now().difference(_lastSpeechTime).inMilliseconds >= 550) {
          // Hanya auto-stop diam jika Hands-Free aktif dan tidak sedang ditahan manual
          _stopRecordingAndSend();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _recording = false;
          _isHolding = false;
        });
        _snack('Gagal miwiti mikrofon.');
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_recording) return;

    _amplitudeSub?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _recording = false;
      _processing = true;
      _audioLevel = 0.0;
      _mascotMood = PillMood.thinking;
    });

    HapticFeedback.lightImpact();

    if (path != null) {
      await _kirimAudio(path);
    } else {
      setState(() {
        _processing = false;
        _mascotMood = PillMood.happy;
      });
    }
  }

  Future<void> _kirimAudio(String path, {String? mockTranscript}) async {
    try {
      final speechService = context.read<AppState>().speech;

      final recent = _history.length > 4 ? _history.sublist(_history.length - 4) : _history;
      final historyPayload = recent.map((h) => {
        'role': h.isUser ? 'user' : 'assistant',
        'content': h.text,
      }).toList();

      final res = await speechService.interactVoiceTutor(
        audioPath: path,
        history: historyPayload,
        contextMode: 'free_talk',
        mockTranscript: mockTranscript,
      );

      if (!mounted) return;

      setState(() {
        if (res.transkripsiSiswa.isNotEmpty || mockTranscript != null) {
          _history.add(ChatTurn(
            isUser: true,
            text: res.transkripsiSiswa.isNotEmpty
                ? res.transkripsiSiswa
                : (mockTranscript ?? ''),
          ));
        }

        _history.add(ChatTurn(
          isUser: false,
          text: res.balasanTeks,
          audioBase64: res.audioBase64,
          audioUrl: res.audioUrl,
          suggestedRepeat: res.suggestedRepeat,
          vocabulary: res.vocabulary,
        ));

        _currentAiSubtitle = res.balasanTeks;
        _lastSpokenAudio = {
          'base64': res.audioBase64,
          'url': res.audioUrl,
        };
        _activeRepeatChallenge = res.suggestedRepeat;

        for (final v in res.vocabulary) {
          if (!_accumulatedVocab
              .any((item) => item.word.toLowerCase() == v.word.toLowerCase())) {
            _accumulatedVocab.add(v);
          }
        }

        _processing = false;
        _mascotMood = _mapMood(res.expression);
        _aiSpeaking = true;
      });

      // Putar audio langsung dari memory base64 / URL
      await _player.setPlaybackRate(_playbackSpeed);
      await TtsPlayback.playBase64OrUrl(
        _player,
        audioBase64: res.audioBase64,
        audioUrl: res.audioUrl,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _mascotMood = PillMood.happy;
      });
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _mascotMood = PillMood.happy;
      });
      _snack('Gagal ngirim audio percakapan.');
    }
  }

  Future<void> _kirimTeks() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _processing || _aiSpeaking) return;

    _textController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _currentAiSubtitle = null;
      _processing = true;
      _mascotMood = PillMood.thinking;
    });

    try {
      String dummyPath = '';
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final dummyFile = File('${tempDir.path}/text_mock.m4a');
        if (!await dummyFile.exists()) {
          await dummyFile.writeAsBytes(List.filled(32, 0));
        }
        dummyPath = dummyFile.path;
      } else {
        dummyPath = 'text_mock.webm';
      }

      await _kirimAudio(dummyPath, mockTranscript: text);
    } catch (_) {
      if (mounted) {
        setState(() {
          _processing = false;
          _mascotMood = PillMood.happy;
        });
        _snack('Gagal ngirim pitakon.');
      }
    }
  }

  Future<void> _replayCurrentSubtitleAudio() async {
    final base64 = _lastSpokenAudio['base64'];
    final url = _lastSpokenAudio['url'];
    if (base64 == null && url == null) {
      if (_currentAiSubtitle != null) {
        await _playChallengeAudio(_currentAiSubtitle!);
      }
      return;
    }

    setState(() {
      _aiSpeaking = true;
      _mascotMood = PillMood.speaking;
    });

    await _player.setPlaybackRate(_playbackSpeed);
    await TtsPlayback.playBase64OrUrl(
      _player,
      audioBase64: base64,
      audioUrl: url,
    );
  }

  Future<void> _playChallengeAudio(String text, {double rate = 1.0}) async {
    try {
      final res = await context.read<AppState>().speech.tts(text);
      await _player.setPlaybackRate(rate);
      setState(() {
        _aiSpeaking = true;
        _mascotMood = PillMood.speaking;
      });
      await TtsPlayback.playTts(_player, res);
    } catch (_) {
      _snack('Gagal muter swanten lafal.');
    }
  }

  PillMood _mapMood(String expression) {
    switch (expression.toLowerCase()) {
      case 'happy':
        return PillMood.happy;
      case 'excited':
        return PillMood.excited;
      case 'thinking':
        return PillMood.thinking;
      case 'sad':
        return PillMood.sad;
      case 'curious':
        return PillMood.curious;
      default:
        return PillMood.speaking;
    }
  }

  void _toggleSpeed() {
    setState(() {
      _playbackSpeed = _playbackSpeed == 1.0 ? 0.8 : 1.0;
    });
    _player.setPlaybackRate(_playbackSpeed);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _showVocabularySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Symbols.auto_stories,
                      color: AppColors.primary700, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kosakata Pasinaon',
                        style: AppFonts.epilogue(
                            size: 18, weight: FontWeight.w800),
                      ),
                      Text(
                        '${_accumulatedVocab.length} tembung anyar kacathet',
                        style: AppFonts.manrope(
                            size: 13, color: AppColors.gray500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Symbols.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.gray100),
            const SizedBox(height: 8),
            if (_accumulatedVocab.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Durung ana tembung sing kacathet ing sesi iki.',
                    style:
                        AppFonts.manrope(size: 14, color: AppColors.gray400),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _accumulatedVocab.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final item = _accumulatedVocab[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primaryFixedDim.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.word,
                                      style: AppFonts.epilogue(
                                          size: 15,
                                          weight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryFixed,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.level,
                                        style: AppFonts.manrope(
                                          size: 10.5,
                                          weight: FontWeight.w700,
                                          color: AppColors.primary800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.meaning,
                                  style: AppFonts.manrope(
                                      size: 13,
                                      color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Symbols.volume_up_rounded,
                                color: AppColors.primary600),
                            onPressed: () => _playChallengeAudio(item.word),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Tutup Rekap',
                  style: AppFonts.epilogue(
                    size: 14,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateTouch(Offset globalPos) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final local = box.globalToLocal(globalPos);
      final center = Offset(box.size.width / 2, 220);
      setState(() {
        _touchOffset = local - center;
      });
    }
  }

  String get _statusSubtitleText {
    if (_recording) return 'Kula mirengaken...';
    if (_processing) return 'Mikir rumiyin...';
    if (_aiSpeaking) return 'Si Swara lagi matur...';
    return 'Aktif · Tutor Wicara Basa Jawa';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Listener(
          onPointerDown: (e) => _updateTouch(e.position),
          onPointerMove: (e) => _updateTouch(e.position),
          onPointerUp: (_) => setState(() => _touchOffset = null),
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: _buildStageContainer(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Panggung Utama AI Voice Tutor (Single Unified Container persis versi Website)
  Widget _buildStageContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Header Bar: Status Sambungan & Pengaturan Cepat
          _buildHeaderBar(),

          const SizedBox(height: 16),
          const Divider(color: AppColors.gray100, height: 1, thickness: 1),
          const SizedBox(height: 18),

          // 2. Center Mascot Stage: PreppyPillAvatar Interaktif (Tombol Mic Utama)
          _buildMascotInteractiveStage(),

          const SizedBox(height: 16),

          // 3. Wadah Subtitle AI (Muncul saat/setelah AI berbicara)
          if (_currentAiSubtitle != null && _currentAiSubtitle!.isNotEmpty) ...[
            _buildAiSubtitleCard(),
            const SizedBox(height: 14),
          ],

          // 4. Kartu Tantangan Tirukan Lafal (Repeat Challenge Card)
          if (_activeRepeatChallenge != null &&
              _activeRepeatChallenge!.isNotEmpty) ...[
            _buildRepeatChallengeCard(),
            const SizedBox(height: 14),
          ],

          const SizedBox(height: 4),
          const Divider(color: AppColors.gray100, height: 1, thickness: 1),
          const SizedBox(height: 14),

          // 5. Footer Bar: Toggle Hands-Free & Opsi Ketik
          _buildFooterBar(),

          // 6. Form Teks Alternatif (Muncul jika tombol ketik dipilih)
          if (_showTextInput) ...[
            const SizedBox(height: 14),
            _buildTextInputForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Row(
      children: [
        if (Navigator.of(context).canPop()) ...[
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                color: AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.arrow_back_rounded,
                  size: 18, color: AppColors.onSurface),
            ),
          ),
        ],

        // Status Si Swara (Live Indicator Dot)
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: AppColors.green500,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.green500.withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Si Swara',
                style: AppFonts.epilogue(
                  size: 15,
                  weight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                _statusSubtitleText,
                style: AppFonts.manrope(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: AppColors.gray500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Kecepatan Audio (1.0x / 0.8x)
        GestureDetector(
          onTap: _toggleSpeed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_playbackSpeed.toStringAsFixed(1)}x',
              style: AppFonts.epilogue(
                size: 12,
                weight: FontWeight.w800,
                color: AppColors.primary700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Rekap Kosakata Sesi
        GestureDetector(
          onTap: _showVocabularySheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryFixedDim),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.auto_stories,
                    size: 16, color: AppColors.primary700),
                const SizedBox(width: 4),
                Text(
                  'Kosakata',
                  style: AppFonts.epilogue(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.primary700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.primary600,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${_accumulatedVocab.length}',
                    style: AppFonts.manrope(
                      size: 10,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Maskot Kapsul Oval Interaktif: User pencet & tahan animasi untuk merekam, lepas auto-selesai
  Widget _buildMascotInteractiveStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: (_) => _handlePointerDown(),
          onPointerUp: (_) => _handlePointerUp(),
          onPointerCancel: (_) => _handlePointerCancel(),
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: _recording ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: PreppyPillAvatar(
              mood: _mascotMood,
              size: 135,
              isSpeaking: _aiSpeaking,
              isRecording: _recording,
              audioLevel: _audioLevel,
              touchOffset: _touchOffset,
              showAudioPulse: _recording || _aiSpeaking,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Badge Petunjuk Mic (Interaktif sesuai state)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _recording
                ? const Color(0xFFFEF2F2)
                : AppColors.primaryFixed,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: _recording
                  ? const Color(0xFFFECACA)
                  : AppColors.primaryFixedDim,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_processing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary700,
                  ),
                )
              else
                Icon(
                  _recording
                      ? Symbols.radio_button_checked_rounded
                      : (_aiSpeaking
                          ? Symbols.volume_up_rounded
                          : Symbols.mic_rounded),
                  size: 17,
                  color: _recording
                      ? const Color(0xFFDC2626)
                      : AppColors.primary700,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _recording
                      ? 'Mirengaken... (Lepas kanggo ngirim)'
                      : (_processing
                          ? 'Si Swara lagi mikir wangsulan...'
                          : (_aiSpeaking
                              ? 'Si Swara lagi matur...'
                              : 'Pencet & tahan Si Swara kanggo wicara')),
                  style: AppFonts.epilogue(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: _recording
                        ? const Color(0xFFDC2626)
                        : AppColors.primary700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Wadah Subtitle AI (Hanya Muncul Saat/Setelah AI Berbicara)
  Widget _buildAiSubtitleCard() {
    final text = _currentAiSubtitle;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryFixedDim.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: AppColors.primary600,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'S',
              style: AppFonts.epilogue(
                size: 12.5,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppFonts.manrope(
                size: 13.5,
                weight: FontWeight.w500,
                color: AppColors.onSurface,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _replayCurrentSubtitleAudio,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryFixedDim),
              ),
              child: const Icon(
                Symbols.volume_up_rounded,
                size: 18,
                color: AppColors.primary700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Kartu Tantangan Tirukan Lafal (Repeat Challenge Card)
  Widget _buildRepeatChallengeCard() {
    final challenge = _activeRepeatChallenge;
    if (challenge == null || challenge.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryFixedDim),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary800.withValues(alpha: 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.record_voice_over,
                color: AppColors.primary700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coba tirukna ukara Jawa iki:',
                  style: AppFonts.manrope(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  challenge,
                  style: AppFonts.epilogue(
                    size: 14,
                    weight: FontWeight.w800,
                    color: AppColors.primary800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _playChallengeAudio(challenge, rate: 0.8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryFixedDim),
              ),
              child: const Icon(
                Symbols.slow_motion_video_rounded,
                size: 18,
                color: AppColors.primary700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Footer Bar: Toggle Hands-Free & Opsi Ketik
  Widget _buildFooterBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Mode Hands-Free Toggle
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 0.8,
              child: Switch.adaptive(
                value: _handsFree,
                activeTrackColor: AppColors.primary600,
                onChanged: (val) {
                  setState(() => _handsFree = val);
                },
              ),
            ),
            Text(
              'Mode Hands-Free',
              style: AppFonts.manrope(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),

        // Tombol Ganti Mode Ketik / Suara
        GestureDetector(
          onTap: () {
            setState(() {
              _showTextInput = !_showTextInput;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showTextInput
                    ? Symbols.mic_rounded
                    : Symbols.keyboard_rounded,
                size: 16,
                color: AppColors.primary700,
              ),
              const SizedBox(width: 4),
              Text(
                _showTextInput ? 'Gunakan Suara' : 'Ketik Pitakon',
                style: AppFonts.manrope(
                  size: 12,
                  weight: FontWeight.w800,
                  color: AppColors.primary700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Form Input Teks Alternatif
  Widget _buildTextInputForm() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gray200),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _kirimTeks(),
              style: AppFonts.manrope(size: 13, color: AppColors.onSurface),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Ketik pitakon utawa ukara Jawa...',
                hintStyle:
                    AppFonts.manrope(size: 12.5, color: AppColors.gray400),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _kirimTeks,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary600,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Symbols.send_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}
