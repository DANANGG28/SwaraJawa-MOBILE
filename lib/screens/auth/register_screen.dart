import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/google_auth_service.dart';
import '../../state/app_state.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/sj_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _nis = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _konfirmasi = TextEditingController();
  String? _kelas;
  String _jenisKelamin = 'L';
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  static const _kelasOptions = ['7A', '7B', '7C', '8A', '8B', '9A'];

  @override
  void dispose() {
    _nama.dispose();
    _nis.dispose();
    _email.dispose();
    _password.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final state = context.read<AppState>();
      final user = await state.auth.registerSiswa(
        namaLengkap: _nama.text.trim(),
        nis: _nis.text.trim(),
        jenisKelamin: _jenisKelamin,
        email: _email.text.trim(),
        password: _password.text,
        kelas: _kelas,
      );
      await state.afterLogin(user);
    } on ApiException catch (e) {
      setState(() => _error = e.firstError);
    } catch (_) {
      setState(() => _error = 'Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _error = null;
      _googleLoading = true;
    });
    try {
      final state = context.read<AppState>();
      final idToken = await state.googleAuth.getIdToken();
      if (idToken == null) return;
      final user = await state.auth.loginWithGoogle(idToken: idToken);
      await state.afterLogin(user);
    } on GoogleAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.firstError);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gagal daftar dengan Google. Silakan coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBright,
      body: DotPatternBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Center(
                    child: AuthCard(
                      maxWidth: 560,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary600,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Image.asset(
                                  'asset/logo/Logo_TP.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Daftar Akun Siswa',
                              textAlign: TextAlign.center,
                              style: AppFonts.epilogue(
                                size: 25,
                                weight: FontWeight.w800,
                                color: AppColors.black900,
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (_error != null) ...[
                              _errorBox(_error!),
                              const SizedBox(height: 16),
                            ],
                            AuthFieldLabel('Nama Lengkap'),
                            const SizedBox(height: 6),
                            AuthTextField(
                              controller: _nama,
                              hint: 'Contoh: Budi Santoso',
                              icon: Symbols.person,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                              ],
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) return 'Nama lengkap wajib diisi.';
                                if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(val)) {
                                  return 'Nama hanya boleh berisi huruf dan spasi.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            AuthFieldLabel('Nomor Induk Siswa (NIS)'),
                            const SizedBox(height: 6),
                            AuthTextField(
                              controller: _nis,
                              hint: 'Contoh: 2026010042',
                              icon: Symbols.pin,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) return 'NIS wajib diisi.';
                                if (!RegExp(r'^[0-9]+$').hasMatch(val)) {
                                  return 'NIS hanya boleh berisi angka.';
                                }
                                if (val.length < 4) return 'NIS minimal 4 digit.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            AuthFieldLabel('Kelas'),
                            const SizedBox(height: 6),
                            _kelasDropdown(),
                            const SizedBox(height: 14),
                            AuthFieldLabel('Jenis Kelamin'),
                            const SizedBox(height: 6),
                            _genderSelector(),
                            const SizedBox(height: 14),
                            AuthFieldLabel('Email Siswa'),
                            const SizedBox(height: 6),
                            AuthTextField(
                              controller: _email,
                              hint: 'nama@sekolah.sch.id',
                              icon: Symbols.mail,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) return 'Email wajib diisi.';
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(val)) {
                                  return 'Format email tidak valid.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            AuthFieldLabel('Kata Sandi'),
                            const SizedBox(height: 6),
                            AuthTextField(
                              controller: _password,
                              hint: 'Minimal 8 karakter',
                              icon: Symbols.lock,
                              obscure: _obscure1,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure1 ? Symbols.visibility : Symbols.visibility_off,
                                  size: 20,
                                  color: AppColors.gray500,
                                ),
                                onPressed: () => setState(() => _obscure1 = !_obscure1),
                              ),
                              validator: (v) {
                                if ((v ?? '').isEmpty) return 'Kata sandi wajib diisi.';
                                if ((v ?? '').length < 8) return 'Kata sandi minimal 8 karakter.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            AuthFieldLabel('Konfirmasi Kata Sandi'),
                            const SizedBox(height: 6),
                            AuthTextField(
                              controller: _konfirmasi,
                              hint: 'Ulangi kata sandi',
                              icon: Symbols.lock,
                              obscure: _obscure2,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure2 ? Symbols.visibility : Symbols.visibility_off,
                                  size: 20,
                                  color: AppColors.gray500,
                                ),
                                onPressed: () => setState(() => _obscure2 = !_obscure2),
                              ),
                              validator: (v) {
                                if ((v ?? '').isEmpty) return 'Konfirmasi kata sandi wajib diisi.';
                                if (v != _password.text) return 'Konfirmasi kata sandi tidak cocok.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            SjButton(
                              label: 'Daftar Akun',
                              icon: Symbols.arrow_forward,
                              loading: _loading,
                              radius: 999,
                              backgroundColor: AppColors.primary700,
                              onPressed: (_loading || _googleLoading) ? null : _submit,
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Expanded(child: Divider(color: AppColors.surfaceContainerHigh, height: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: SjLabelUpper('atau', size: 11, letterSpacing: 1.4),
                                ),
                                const Expanded(child: Divider(color: AppColors.surfaceContainerHigh, height: 1)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _googleButton(),
                            const SizedBox(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sudah punya akun?',
                                  style: AppFonts.manrope(size: 13, color: AppColors.onSurfaceVariant),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Text(
                                    ' Masuk di sini',
                                    style: AppFonts.manrope(
                                      size: 13,
                                      weight: FontWeight.w800,
                                      color: AppColors.primary700,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '© 2025 SINAU APP. Hak Cipta Dilindungi.',
                  style: AppFonts.manrope(size: 11, color: AppColors.gray500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Symbols.close, size: 26, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }

  Widget _kelasDropdown() {
    return DropdownButtonFormField<String>(
      value: _kelas,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        prefixIcon: const Icon(Symbols.school, size: 22, color: AppColors.gray500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary600, width: 1.5),
        ),
      ),
      hint: Text('Pilih Kelas', style: AppFonts.manrope(size: 14, color: AppColors.gray500)),
      items: _kelasOptions
          .map((k) => DropdownMenuItem(
                value: k,
                child: Text(k, style: AppFonts.manrope(size: 14, weight: FontWeight.w600)),
              ))
          .toList(),
      onChanged: (v) => setState(() => _kelas = v),
    );
  }

  Widget _genderSelector() {
    Widget item(String value, String label, String subtitle, IconData icon, Color bg, Color fg) {
      final selected = _jenisKelamin == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _jenisKelamin = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryFixed : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary600 : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: fg),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppFonts.manrope(size: 13, weight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        style: AppFonts.manrope(size: 10, color: AppColors.gray500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item('L', 'Laki-laki', 'Siswa (L)', Symbols.male, const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
        const SizedBox(width: 10),
        item('P', 'Perempuan', 'Siswi (P)', Symbols.female, AppColors.pink100, const Color(0xFFBE185D)),
      ],
    );
  }

  Widget _googleButton() {
    return GestureDetector(
      onTap: (_googleLoading || _loading) ? null : _submitGoogle,
      child: Opacity(
        opacity: (_googleLoading || _loading) ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_googleLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const _GoogleIcon(),
              const SizedBox(width: 12),
              Text(
                _googleLoading ? 'MENGHUBUNGKAN...' : 'DAFTAR DENGAN GOOGLE',
                style: AppFonts.manrope(
                  size: 13,
                  weight: FontWeight.w800,
                  color: AppColors.black900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: AppFonts.manrope(size: 13, color: const Color(0xFF93000A)),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final stroke = size.width * 0.24;
    final rect = Rect.fromCircle(center: c, radius: r - stroke / 2);

    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(const Color(0xFF4285F4), -0.35, 1.35);
    arc(const Color(0xFF34A853), 1.0, 1.15);
    arc(const Color(0xFFFBBC05), 2.15, 1.1);
    arc(const Color(0xFFEA4335), 3.25, 1.35);

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTRB(r * 1.05, r * 0.72, size.width - 1, r * 1.28),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
