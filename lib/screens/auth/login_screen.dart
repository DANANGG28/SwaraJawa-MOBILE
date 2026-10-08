import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../services/google_auth_service.dart';
import '../../state/app_state.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/sj_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final state = context.read<AppState>();
      final user = await state.auth.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      await state.afterLogin(user);
    } on ApiException catch (e) {
      setState(() => _error = e.firstError);
    } catch (e) {
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
        setState(() => _error = 'Gagal masuk dengan Google. Silakan coba lagi.');
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _header(),
                            const SizedBox(height: 26),
                            if (_error != null) ...[
                              _errorBox(_error!),
                              const SizedBox(height: 16),
                            ],
                            const AuthFieldLabel('Email'),
                            const SizedBox(height: 6),
                            AuthTextField(
                              controller: _email,
                              hint: 'nama@sekolah.sch.id',
                              icon: Symbols.mail,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Email wajib diisi.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AuthFieldLabel(
                              'Kata Sandi',
                              trailing: GestureDetector(
                                onTap: () => _showInfo(
                                    'Buka halaman lupa sandi melalui website SINAU APP.'),
                                child: const SjLabelUpper(
                                  'Lupa?',
                                  size: 11,
                                  color: AppColors.primary600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            AuthTextField(
                              controller: _password,
                              hint: 'Masukkan kata sandi',
                              icon: Symbols.lock,
                              obscure: _obscure,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure ? Symbols.visibility : Symbols.visibility_off,
                                  color: AppColors.gray500,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Kata sandi wajib diisi.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _rememberRow(),
                            const SizedBox(height: 16),
                            SjButton(
                              label: 'Masuk',
                              upper: true,
                              loading: _loading,
                              radius: 16,
                              onPressed: (_loading || _googleLoading) ? null : _submit,
                            ),
                            const SizedBox(height: 22),
                            _orDivider('atau'),
                            const SizedBox(height: 16),
                            _googleButton(),
                            const SizedBox(height: 22),
                            _footer(),
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
                  '© 2025 SINAU APP. Platform Pembelajaran Bahasa Jawa Interaktif.',
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
            onPressed: () => _showInfo('Halaman masuk adalah gerbang utama aplikasi.'),
            icon: const Icon(Symbols.close, size: 26, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
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
        const SizedBox(height: 12),
        Text(
          'Masuk',
          style: AppFonts.epilogue(size: 25, weight: FontWeight.w800, color: AppColors.black900),
        ),
      ],
    );
  }

  Widget _rememberRow() {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? true),
            activeColor: AppColors.primary600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Text('Ingat saya', style: AppFonts.manrope(size: 12, color: AppColors.gray500)),
      ],
    );
  }

  Widget _orDivider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.gray200, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SjLabelUpper(text, size: 11, letterSpacing: 2),
        ),
        const Expanded(child: Divider(color: AppColors.gray200, height: 1)),
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
                _googleLoading ? 'MENGHUBUNGKAN...' : 'MASUK DENGAN GOOGLE',
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

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Belum punya akun? ',
          style: AppFonts.manrope(size: 12, color: AppColors.gray500),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: Text(
            'Daftar akun siswa',
            style: AppFonts.manrope(
              size: 12,
              weight: FontWeight.w800,
              color: AppColors.primary600,
            ),
          ),
        ),
      ],
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

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
