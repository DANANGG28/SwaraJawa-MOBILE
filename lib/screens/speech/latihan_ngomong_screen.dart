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
import '../../models/soal.dart';
import '../../models/voice_tutor.dart';
import '../../state/app_state.dart';
import '../../widgets/preppy_pill_avatar.dart';

enum VoiceRoomMode {
  voiceTutor, // Percakapan bebas dua arah dengan Si Swara (GoPrep style)
  quizSoal,   // Latihan pengucapan kalimat kuis materi kurikulum
}

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

  // Mode ruangan
  final VoiceRoomMode _currentMode = VoiceRoomMode.voiceTutor;

  // State percakapan
  final List<ChatTurn> _history = [];
  final List<VoiceTutorVocabulary> _accumulatedVocab = [];

  // Data kuis acuan jika mode kuis
  Soal? _soal;
  // Status perekaman & AI
  bool _recording = false;
  bool _processing = false;
  bool _aiSpeaking = false;
  double _audioLevel = 0.0;
  StreamSubscription<Amplitude>? _amplitudeSub;

  // Mood maskot Si Swara
  PillMood _mascotMood = PillMood.happy;
  Offset? _touchOffset;

  // Pengaturan interaksi
  bool _handsFree = true;
  double _playbackSpeed = 1.0;
  DateTime _lastSpeechTime = DateTime.now();
  Timer? _silenceTimer;

  // Kalimat tantangan peniruan terkini
  String? _activeRepeatChallenge;

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

      // Jika mode hands-free aktif, otomatis dengarkan respon siswa
      if (_handsFree && !_recording && !_processing) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_aiSpeaking && !_recording) {
            _startRecording();
          }
        });
      }
    });
  }

  void _loadInitialGreeting() {
    _history.add(ChatTurn(
      isUser: false,
      text: 'Sugeng rawuh! Kula Si Swara, kanca sinau panjenengan. Mangga wicara Basa Jawa utawa takon apa wae!',
      suggestedRepeat: 'Sugeng enjang, Mas Swara',
      vocabulary: [
        const VoiceTutorVocabulary(word: 'Sugeng rawuh', meaning: 'Selamat datang', level: 'Krama'),
        const VoiceTutorVocabulary(word: 'Kanca', meaning: 'Teman / Kawan', level: 'Ngoko'),
      ],
    ));
    _activeRepeatChallenge = 'Sugeng enjang, Mas Swara';
    _accumulatedVocab.addAll(_history.first.vocabulary);
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  RecordConfig _recordConfig() => kIsWeb
      ? const RecordConfig(encoder: AudioEncoder.opus)
      : const RecordConfig(encoder: AudioEncoder.aacLc);

  Future<void> _startRecording() async {
    if (_processing || _aiSpeaking || _recording) return;

    try {
      if (!await _recorder.hasPermission()) {
        _snack('Izin mikrofon dibutuhake kanggo wicara.');
        return;
      }

      await _player.stop();

      final path = kIsWeb
          ? 'tutor_${DateTime.now().millisecondsSinceEpoch}.webm'
          : '${(await getTemporaryDirectory()).path}/tutor_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(_recordConfig(), path: path);

      setState(() {
        _recording = true;
        _mascotMood = PillMood.neutral;
        _lastSpeechTime = DateTime.now();
      });

      // Monitor amplitudo & Fast VAD (500ms hening auto-stop)
      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        if (!mounted) return;
        final currentDb = amp.current;
        final normalized = ((currentDb + 45.0) / 45.0).clamp(0.0, 1.0);

        setState(() => _audioLevel = normalized);

        // Jika suara di atas batas -36dB, perbarui waktu bicara
        if (currentDb > -36.0) {
          _lastSpeechTime = DateTime.now();
        } else if (_handsFree && DateTime.now().difference(_lastSpeechTime).inMilliseconds >= 550) {
          // Diam 550ms -> otomatis kirim suara
          _stopRecordingAndSend();
        }
      });
    } catch (_) {
      _snack('Gagal miwiti mikrofon.');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_recording) return;

    _amplitudeSub?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}

    setState(() {
      _recording = false;
      _processing = true;
      _audioLevel = 0.0;
      _mascotMood = PillMood.thinking;
    });

    if (path != null) {
      await _kirimAudio(path);
    } else {
      setState(() {
        _processing = false;
        _mascotMood = PillMood.neutral;
      });
    }
  }

  Future<void> _kirimAudio(String path) async {
    try {
      final speechService = context.read<AppState>().speech;

      if (_currentMode == VoiceRoomMode.voiceTutor) {
        // Mode Voice Tutor GoPrep Free-Form
        final recent = _history.length > 4 ? _history.sublist(_history.length - 4) : _history;
        final historyPayload = recent.map((h) => {
          'role': h.isUser ? 'user' : 'assistant',
          'content': h.text,
        }).toList();

        final res = await speechService.interactVoiceTutor(
          audioPath: path,
          history: historyPayload,
          contextMode: 'free_talk',
        );

        if (!mounted) return;

        setState(() {
          _history.add(ChatTurn(isUser: true, text: res.transkripsiSiswa));
          _history.add(ChatTurn(
            isUser: false,
            text: res.balasanTeks,
            audioBase64: res.audioBase64,
            audioUrl: res.audioUrl,
            suggestedRepeat: res.suggestedRepeat,
            vocabulary: res.vocabulary,
          ));

          _activeRepeatChallenge = res.suggestedRepeat;
          for (final v in res.vocabulary) {
            if (!_accumulatedVocab.any((item) => item.word.toLowerCase() == v.word.toLowerCase())) {
              _accumulatedVocab.add(v);
            }
          }

          _processing = false;
          _mascotMood = _mapMood(res.expression);
          _aiSpeaking = true;
        });

        // Putar audio langsung dari memory base64 (zero-roundtrip)
        await _player.setPlaybackRate(_playbackSpeed);
        await TtsPlayback.playBase64OrUrl(
          _player,
          audioBase64: res.audioBase64,
          audioUrl: res.audioUrl,
        );
      } else {
        // Mode Kuis Soal Kurikulum
        final soal = _soal;
        if (soal == null) {
          setState(() {
            _processing = false;
            _mascotMood = PillMood.neutral;
          });
          return;
        }

        final res = await speechService.latihanNgomong(
          soal.id,
          audioPath: path,
        );

        if (!mounted) return;

        setState(() {
          _history.add(ChatTurn(isUser: true, text: res.transkripsi));
          _history.add(ChatTurn(
            isUser: false,
            text: res.feedbackText ?? 'Pangucapan panjenengan sae sanget!',
            audioBase64: res.audioBase64,
            audioUrl: res.audioUrl,
          ));
          _processing = false;
          _mascotMood = PillMood.happy;
          _aiSpeaking = true;
        });

        await _player.setPlaybackRate(_playbackSpeed);
        await TtsPlayback.playBase64OrUrl(
          _player,
          audioBase64: res.audioBase64,
          audioUrl: res.audioUrl,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _mascotMood = PillMood.sad;
      });
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _mascotMood = PillMood.sad;
      });
      _snack('Gagal ngirim audio percakapan.');
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
                  child: const Icon(Symbols.auto_stories, color: AppColors.primary700, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kosakata Pasinaon',
                        style: AppFonts.epilogue(size: 19, weight: FontWeight.w800),
                      ),
                      Text(
                        '${_accumulatedVocab.length} tembung anyar kacathet',
                        style: AppFonts.manrope(size: 13, color: AppColors.gray500),
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
                    style: AppFonts.manrope(size: 14, color: AppColors.gray400),
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
                        border: Border.all(color: AppColors.primaryFixedDim.withValues(alpha: 0.5)),
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
                                      style: AppFonts.epilogue(size: 16, weight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryFixed,
                                        borderRadius: BorderRadius.circular(6),
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
                                  style: AppFonts.manrope(size: 13, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Symbols.volume_up_rounded, color: AppColors.primary600),
                            onPressed: () => _playChallengeAudio(item.word),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
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
          child: Column(
            children: [
              // 1. Header panggung minimalis ala GoPrep
              _buildTopBar(),

              // 2. Stage Utama: PreppyPill Mascot + Live LipSync + Audio Pulse Rings
              _buildMascotStage(),

              // 3. Kartu Tantangan Tirukan Suara (jika ada target lafal)
              if (_activeRepeatChallenge != null) _buildRepeatChallengeCard(),

              // 4. Area Transkrip Dialog Ringkas
              Expanded(child: _buildTranscriptArea()),

              // 5. Dock Kontrol Melayang Bawah (Mic Kapsul Besar + Hands-Free Toggle)
              _buildControlDock(),
            ],
          ),
        ),
      ),
    );
  }

  void _updateTouch(Offset globalPos) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final local = box.globalToLocal(globalPos);
      final center = Offset(box.size.width / 2, 190);
      setState(() {
        _touchOffset = local - center;
      });
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Tombol Kembali
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gray200),
              ),
              child: const Icon(Symbols.arrow_back_rounded, size: 20, color: AppColors.onSurface),
            ),
          ),
          const SizedBox(width: 10),

          // Live Pill Badge Status Sambungan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.green500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _aiSpeaking
                      ? 'Si Swara matur...'
                      : (_recording ? 'Kula mirengaken...' : 'Si Swara · Aktif'),
                  style: AppFonts.manrope(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Kecepatan Suara Toggle (1.0x / 0.8x)
          GestureDetector(
            onTap: () {
              setState(() {
                _playbackSpeed = _playbackSpeed == 1.0 ? 0.8 : 1.0;
              });
              _player.setPlaybackRate(_playbackSpeed);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gray200),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: AppFonts.manrope(
                  size: 12,
                  weight: FontWeight.w800,
                  color: AppColors.primary700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Lembar Kosakata (Session Feedback ala GoPrep)
          GestureDetector(
            onTap: _showVocabularySheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryFixedDim),
              ),
              child: const Icon(Symbols.auto_stories, size: 18, color: AppColors.primary700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotStage() {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Center(
        child: PreppyPillAvatar(
          mood: _mascotMood,
          size: 135,
          isSpeaking: _aiSpeaking,
          audioLevel: _audioLevel,
          touchOffset: _touchOffset,
          showAudioPulse: _recording || _aiSpeaking,
          onTap: () {
            // Tap maskot untuk menyapa / mengganti ekspresi ceria
            setState(() {
              _mascotMood = PillMood.happy;
            });
          },
        ),
      ),
    );
  }

  Widget _buildRepeatChallengeCard() {
    final challenge = _activeRepeatChallenge;
    if (challenge == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryFixedDim),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary800.withValues(alpha: 0.05),
              offset: const Offset(0, 4),
              blurRadius: 10,
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
              child: const Icon(Symbols.record_voice_over, color: AppColors.primary700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coba tirukna lafal iki:',
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
                      size: 14.5,
                      weight: FontWeight.w800,
                      color: AppColors.primary800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Symbols.slow_motion_video_rounded, color: AppColors.primary600),
              tooltip: 'Rungokna alon (0.8x)',
              onPressed: () => _playChallengeAudio(challenge, rate: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptArea() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        if (item.isUser) {
          return Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: const BoxDecoration(
                color: AppColors.primary700,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                item.text,
                style: AppFonts.manrope(size: 13.5, color: Colors.white, weight: FontWeight.w600),
              ),
            ),
          );
        } else {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 290),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.gray200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.text,
                      style: AppFonts.manrope(size: 13.5, color: AppColors.onSurface, weight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _playChallengeAudio(item.text),
                    child: const Icon(Symbols.volume_up_rounded, size: 18, color: AppColors.primary600),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildControlDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baris Toggle Hands-Free
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Mode Hands-Free (Otomatis)',
                style: AppFonts.manrope(size: 12.5, weight: FontWeight.w700, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: _handsFree,
                activeTrackColor: AppColors.primary600,
                onChanged: (val) {
                  setState(() => _handsFree = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Tombol Mic Kapsul Utama Ala GoPrep
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Tombol Kosakata
              IconButton(
                icon: const Icon(Symbols.menu_book_rounded, color: AppColors.gray500, size: 26),
                tooltip: 'Kosakata Sesi',
                onPressed: _showVocabularySheet,
              ),

              // Tombol Mic Tengah Besar (Diameter 76px)
              GestureDetector(
                onTap: () {
                  if (_recording) {
                    _stopRecordingAndSend();
                  } else {
                    _startRecording();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _recording
                          ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                          : [AppColors.brand500, AppColors.primary700],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_recording ? const Color(0xFFDC2626) : AppColors.brand500).withValues(alpha: 0.38),
                        blurRadius: _recording ? 24 : 16,
                        spreadRadius: _recording ? 4 : 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _processing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : Icon(
                            _recording ? Symbols.stop_rounded : Symbols.mic_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),

              // Tombol Akhiri Sesi
              IconButton(
                icon: const Icon(Symbols.check_circle_outline_rounded, color: AppColors.green600, size: 26),
                tooltip: 'Rampung',
                onPressed: () {
                  _showVocabularySheet();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _recording
                ? 'Ngrungokake swara panjenengan...'
                : (_processing ? 'Si Swara lagi mikir...' : 'Tutul mic kanggo wicara'),
            style: AppFonts.manrope(size: 11.5, weight: FontWeight.w600, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }
}
