import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../models/chat.dart';
import '../../state/app_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<ChatMessageItem> _messages = [];
  List<ChatSessionInfo> _sessions = [];
  int? _activeSessionId;
  bool _busy = false;
  bool _typing = false;
  bool _sessionsLoaded = false;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _maxTimer;
  bool _recording = false;
  bool _transcribing = false;
  bool _hasSpoken = false;
  int _silenceMs = 0;
  DateTime? _micStart;

  @override
  void initState() {
    super.initState();
    _resetToWelcome();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _maxTimer?.cancel();
    _recorder.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _resetToWelcome() {
    final nama = context.read<AppState>().siswa?.namaLengkap ?? 'Siswa';
    _messages
      ..clear()
      ..add(ChatMessageItem(
        role: 'assistant',
        pesan:
            'Sugeng rawuh, $nama ! Kula Semar AI, rencang panjenengan anggenipun sinau Basa Jawi. Sumangga tanglet bab unggah-ungguh basa (Ngoko, Krama, Krama Alus), aksara Jawa, tembung saroja, peribahasa, tuwin kabudayan Jawa.',
      ));
    _activeSessionId = null;
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await context.read<AppState>().chat.histori();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _sessionsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _sessionsLoaded = true);
    }
  }

  Future<void> _ask(String text) async {
    final pertanyaan = text.trim();
    if (pertanyaan.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _messages.add(ChatMessageItem(role: 'user', pesan: pertanyaan));
      _busy = true;
      _typing = true;
    });
    _scrollDown();
    try {
      final res = await context.read<AppState>().chat.tanya(
            pertanyaan: pertanyaan,
            sessionId: _activeSessionId,
          );
      if (!mounted) return;
      setState(() {
        _typing = false;
        _activeSessionId = res.sessionId ?? _activeSessionId;
        _messages.add(ChatMessageItem(
          role: 'assistant',
          pesan: res.jawaban.isEmpty
              ? 'Mohon maaf, saya belum dapat menjawab pertanyaan tersebut.'
              : res.jawaban,
          sumber: res.sumber,
        ));
        _busy = false;
        _upsertSession(res.sessionId, res.sessionTitle ?? _limit(pertanyaan));
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _busy = false;
        _messages.add(const ChatMessageItem(
          role: 'assistant',
          pesan: 'Mohon maaf, terjadi gangguan teknis. Silakan coba lagi.',
        ));
      });
      if (e.statusCode == 429) {
        _snack('Mohon maaf, Anda mengirim pertanyaan terlalu cepat. Silakan tunggu beberapa saat lagi.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _busy = false;
        _messages.add(const ChatMessageItem(
          role: 'assistant',
          pesan: 'Mohon maaf, koneksi ke asisten gagal. Silakan periksa koneksi internet Anda.',
        ));
      });
    }
    _scrollDown();
  }

  String _limit(String text) =>
      text.length <= 45 ? text : '${text.substring(0, 42)}...';

  void _upsertSession(int? id, String title) {
    if (id == null) return;
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index >= 0) {
      _sessions.removeAt(index);
    }
    _sessions.insert(0, ChatSessionInfo(id: id, judul: title));
  }

  Future<void> _openSession(ChatSessionInfo session) async {
    Navigator.of(context).maybePop();
    setState(() {
      _busy = true;
      _typing = false;
      _messages.clear();
      _activeSessionId = session.id;
    });
    try {
      final messages = await context.read<AppState>().chat.detailSesi(session.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages.isEmpty
              ? [const ChatMessageItem(role: 'assistant', pesan: 'Belum ada pesan pada sesi ini.')]
              : messages);
        _busy = false;
      });
      _scrollDown();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messages.add(const ChatMessageItem(
          role: 'assistant',
          pesan: 'Mohon maaf, riwayat obrolan tidak dapat dibuka. Silakan coba lagi.',
        ));
      });
    }
  }

  Future<void> _deleteSession(ChatSessionInfo session) async {
    final chat = context.read<AppState>().chat;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus riwayat obrolan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await chat.hapusSesi(session.id);
      if (!mounted) return;
      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
        if (_activeSessionId == session.id) _resetToWelcome();
      });
    } catch (_) {
      _snack('Gagal menghapus riwayat. Silakan coba lagi.');
    }
  }

  void _newChat() {
    setState(_resetToWelcome);
    Navigator.of(context).maybePop();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static const _speechThresholdDb = -38.0;
  static const _silenceTimeoutMs = 1200;
  static const _noSpeechTimeoutMs = 5000;
  static const _maxRecordMs = 10000;

  RecordConfig _micConfig() => kIsWeb
      ? const RecordConfig(encoder: AudioEncoder.opus)
      : const RecordConfig(encoder: AudioEncoder.aacLc);

  Future<void> _toggleMic() async {
    if (_transcribing) return;
    if (_recording) {
      await _stopMic();
    } else {
      await _startMic();
    }
  }

  Future<void> _startMic() async {
    try {
      if (!await _recorder.hasPermission()) {
        _snack('Izin mikrofon ditolak. Aktifkan izin mikrofon untuk aplikasi ini.');
        return;
      }
      final path = kIsWeb
          ? 'chat_${DateTime.now().millisecondsSinceEpoch}.webm'
          : '${(await getTemporaryDirectory()).path}/chat_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(_micConfig(), path: path);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _hasSpoken = false;
        _silenceMs = 0;
        _micStart = DateTime.now();
      });
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 200))
          .listen(_onAmplitude);
      _maxTimer = Timer(const Duration(milliseconds: _maxRecordMs), _stopMic);
    } catch (_) {
      _snack('Mikrofon tidak tersedia.');
    }
  }

  void _onAmplitude(Amplitude a) {
    if (!_recording) return;
    if (a.current > _speechThresholdDb) {
      _hasSpoken = true;
      _silenceMs = 0;
      return;
    }
    if (!_hasSpoken) {
      final elapsed =
          DateTime.now().difference(_micStart ?? DateTime.now()).inMilliseconds;
      if (elapsed >= _noSpeechTimeoutMs) _stopMic();
      return;
    }
    _silenceMs += 200;
    if (_silenceMs >= _silenceTimeoutMs) _stopMic();
  }

  Future<void> _stopMic() async {
    if (!_recording) return;
    final speech = context.read<AppState>().speech;
    final wasSpoken = _hasSpoken;
    _maxTimer?.cancel();
    _ampSub?.cancel();
    _ampSub = null;
    setState(() {
      _recording = false;
      _transcribing = true;
    });
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    try {
      if (!wasSpoken) {
        _snack('Tidak ada ucapan yang terdeteksi.');
        return;
      }
      if (path == null) {
        _snack('Rekaman gagal. Silakan coba lagi.');
        return;
      }
      final b64 = await speech.audioBase64FromPath(path);
      final text = (await speech.stt(b64)).trim();
      if (!mounted) return;
      if (text.isEmpty) {
        _snack('Tidak ada ucapan yang terdeteksi.');
        return;
      }
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal mengubah suara menjadi teks. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      drawer: _historyDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(child: _messagesList()),
            _inputArea(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: AppColors.surfaceContainer)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), offset: Offset(0, 1), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Symbols.history, size: 22, color: AppColors.primary700),
            ),
          ),
          const Spacer(),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.smart_toy, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Semar AI', style: AppFonts.epilogue(size: 12, weight: FontWeight.w800)),
              Text(
                'Tanya Basa Jawa',
                style: AppFonts.manrope(
                  size: 10,
                  weight: FontWeight.w600,
                  color: AppColors.primary600,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _newChat,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Symbols.add, size: 22, color: AppColors.primary700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messagesList() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      children: [
        Center(
          child: Text(
            'Tanya apa saja seputar Basa Jawa',
            textAlign: TextAlign.center,
            style: AppFonts.epilogue(size: 20, weight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 20),
        for (final m in _messages) _message(m),
        if (_typing) _typingBubble(),
      ],
    );
  }

  Widget _message(ChatMessageItem m) {
    if (m.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primary700,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Text(
              m.pesan,
              style: AppFonts.manrope(size: 12, color: Colors.white, height: 1.5),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.smart_toy, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceContainer),
                boxShadow: const [
                  BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WANGSULAN SEMAR AI',
                    style: AppFonts.manrope(
                      size: 10,
                      weight: FontWeight.w800,
                      color: AppColors.gray500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.pesan,
                    style: AppFonts.manrope(size: 12, height: 1.6),
                  ),
                  if (m.sumber.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.surfaceContainer)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Symbols.menu_book, size: 14, color: AppColors.gray500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Sumber korpus: ${m.sumber.join('; ')}',
                              style: AppFonts.manrope(size: 12, color: AppColors.gray500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.smart_toy, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceContainer),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary500,
                        shape: BoxShape.circle,
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

  Widget _inputArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.surfaceContainer),
              boxShadow: const [
                BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -1),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _transcribing ? null : _toggleMic,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: _transcribing
                        ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _recording ? Symbols.stop : Symbols.mic,
                            size: 20,
                            color: _recording ? AppColors.error : AppColors.gray500,
                          ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _ask,
                    style: AppFonts.manrope(size: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Ketik pitakon basa Jawa ing kene...',
                      hintStyle: AppFonts.manrope(size: 12, color: AppColors.gray500),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _busy ? null : () => _ask(_controller.text),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _busy
                          ? AppColors.primary700.withValues(alpha: 0.5)
                          : AppColors.primary700,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Symbols.send, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          if (_recording || _transcribing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _recording
                    ? 'Merekam… tap ikon berhenti untuk menghentikan'
                    : 'Mengubah suara menjadi teks…',
                textAlign: TextAlign.center,
                style: AppFonts.manrope(size: 10, color: AppColors.gray500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Riwayat Obrolan',
                    style: AppFonts.epilogue(size: 15, weight: FontWeight.w800),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Symbols.arrow_back, size: 20),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.surfaceContainer),
              GestureDetector(
                onTap: _newChat,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Symbols.add, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Obrolan Anyar',
                        style: AppFonts.manrope(
                          size: 13,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: !_sessionsLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : _sessions.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada riwayat obrolan',
                              style: AppFonts.manrope(
                                size: 12,
                                color: AppColors.gray500,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _sessions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final s = _sessions[i];
                              return Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _openSession(s),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: s.id == _activeSessionId
                                              ? AppColors.surfaceContainerLow
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Symbols.chat_bubble_outline, size: 16, color: AppColors.gray500),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                s.judul,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppFonts.manrope(
                                                  size: 12,
                                                  weight: s.id == _activeSessionId
                                                      ? FontWeight.w800
                                                      : FontWeight.w500,
                                                  color: s.id == _activeSessionId
                                                      ? AppColors.primary700
                                                      : AppColors.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _deleteSession(s),
                                    child: const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: Icon(Symbols.delete, size: 16, color: AppColors.gray400),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
