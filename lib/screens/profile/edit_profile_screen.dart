import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../state/app_state.dart';
import '../../widgets/sj_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _nis;
  late final TextEditingController _email;
  late final TextEditingController _telpon;
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  String? _kelas;
  String _jenisKelamin = 'L';
  File? _foto;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _saving = false;

  static const _kelasOptions = ['7A', '7B', '7C', '8A', '8B', '9A'];

  @override
  void initState() {
    super.initState();
    final siswa = context.read<AppState>().siswa;
    _nama = TextEditingController(text: siswa?.namaLengkap ?? '');
    _nis = TextEditingController(text: siswa?.nis ?? '');
    _email = TextEditingController(text: siswa?.email ?? '');
    _telpon = TextEditingController(text: siswa?.noTelpon ?? '');
    _kelas = (siswa?.kelas != null && _kelasOptions.contains(siswa!.kelas)) ? siswa.kelas : null;
    _jenisKelamin = siswa?.jenisKelamin == 'P' ? 'P' : 'L';
  }

  @override
  void dispose() {
    _nama.dispose();
    _nis.dispose();
    _email.dispose();
    _telpon.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  int get _persenLengkap {
    var filled = 0;
    const total = 6;
    if (_nama.text.trim().isNotEmpty) filled++;
    if (_nis.text.trim().isNotEmpty) filled++;
    if (_kelas != null && _kelas!.isNotEmpty) filled++;
    if (_jenisKelamin.isNotEmpty) filled++;
    if (_email.text.trim().isNotEmpty) filled++;
    if (_telpon.text.trim().isNotEmpty || _foto != null) filled++;
    return ((filled / total) * 100).round();
  }

  Future<void> _pickFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final size = await picked.length();
    if (size > 2 * 1024 * 1024) {
      _snack('Ukuran foto melebihi 2 MB. Silakan pilih foto dengan ukuran lebih kecil.');
      return;
    }
    setState(() => _foto = File(picked.path));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final appState = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final form = FormData.fromMap({
        '_method': 'PUT',
        'nama_lengkap': _nama.text.trim(),
        'nis': _nis.text.trim(),
        'jenis_kelamin': _jenisKelamin,
        'kelas': _kelas,
        'email': _email.text.trim(),
        'no_telpon': _telpon.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
        if (_foto != null)
          'foto': await MultipartFile.fromFile(_foto!.path, filename: 'foto.jpg'),
      });
      await appState.client.postMultipart('/profil/data', formData: form);
      if (!mounted) return;
      await appState.refreshSiswa();
      if (!mounted) return;
      _snack('Perubahan berhasil disimpan.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _snack(e.statusCode == 404 || e.statusCode == 405
          ? 'Fitur simpan profil belum tersedia pada server. Hubungi admin.'
          : e.firstError);
    } catch (_) {
      _snack('Gagal menyimpan perubahan.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _header(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _statusBanner(),
                    const SizedBox(height: 20),
                    _fotoSection(),
                    const SizedBox(height: 20),
                    _dataSection(),
                    const SizedBox(height: 20),
                    _kontakSection(),
                    const SizedBox(height: 20),
                    _passwordSection(),
                    const SizedBox(height: 24),
                    _actions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xE6FFFFFF),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: AppColors.gray50, shape: BoxShape.circle),
              child: const Icon(Symbols.arrow_back, size: 20, color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Profil', style: AppFonts.manrope(size: 12, weight: FontWeight.w600, color: AppColors.gray500)),
                    Text(' / ', style: AppFonts.manrope(size: 12, color: AppColors.gray500)),
                    Text(
                      'Edit Data',
                      style: AppFonts.manrope(size: 12, weight: FontWeight.w800, color: AppColors.primary600),
                    ),
                  ],
                ),
                Text(
                  'Lengkapi Data Diri',
                  style: AppFonts.epilogue(size: 16, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final lengkap = _persenLengkap >= 100;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: lengkap ? const Color(0xFFF0FDF4) : AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  lengkap ? Symbols.task_alt : Symbols.assignment_ind,
                  size: 30,
                  color: lengkap ? AppColors.green600 : AppColors.primary600,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Kelengkapan Data Diri',
                      style: AppFonts.epilogue(size: 18, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: lengkap ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Symbols.verified, size: 14, color: lengkap ? AppColors.green600 : const Color(0xFFB45309)),
                          const SizedBox(width: 4),
                          Text(
                            lengkap ? 'Lengkap 100%' : '$_persenLengkap% Selesai',
                            style: AppFonts.manrope(
                              size: 12,
                              weight: FontWeight.w800,
                              color: lengkap ? const Color(0xFF15803D) : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lengkap
                          ? 'Semua data profil Anda sudah terisi lengkap. Anda tetap dapat memperbarui informasi kapan saja.'
                          : 'Lengkapi foto profil dan data diri Anda untuk memaksimalkan pengalaman belajar di SINAU APP.',
                      style: AppFonts.manrope(size: 12, color: AppColors.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kemajuan Profil', style: AppFonts.manrope(size: 12, weight: FontWeight.w800, color: AppColors.gray500)),
                    Text(
                      '$_persenLengkap%',
                      style: AppFonts.manrope(
                        size: 12,
                        weight: FontWeight.w800,
                        color: lengkap ? AppColors.green600 : AppColors.primary600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 10,
                    color: AppColors.gray200.withValues(alpha: 0.8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (_persenLengkap / 100).clamp(0.0, 1.0),
                        child: Container(color: lengkap ? AppColors.green500 : AppColors.primary600),
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

  Widget _fotoSection() {
    final siswa = context.watch<AppState>().siswa;
    return _section(
      icon: Symbols.account_box,
      title: 'Foto Profil Siswa',
      subtitle: 'Gunakan foto wajah yang jelas, sopan, atau berseragam sekolah.',
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 128,
                height: 128,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray200.withValues(alpha: 0.7)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -1),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _foto != null
                      ? Image.file(_foto!, fit: BoxFit.cover, width: 124, height: 124)
                      : _networkOrInitials(siswa),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: GestureDetector(
                  onTap: _pickFoto,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: AppColors.primary600, shape: BoxShape.circle),
                    child: const Icon(Symbols.photo_camera, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _pickFoto,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.primary600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.cloud_upload, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Pilih Foto Baru', style: AppFonts.manrope(size: 14, weight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Mendukung format JPG, PNG, atau WEBP. Ukuran file maksimal 2 MB.',
            textAlign: TextAlign.center,
            style: AppFonts.manrope(size: 12, color: AppColors.gray500),
          ),
          if (_foto != null) ...[
            const SizedBox(height: 8),
            Text(
              _foto!.path.split(Platform.pathSeparator).last,
              style: AppFonts.manrope(size: 12, weight: FontWeight.w700, color: AppColors.primary700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _networkOrInitials(dynamic siswa) {
    final raw = siswa?.fotoUrl as String?;
    if (raw != null && raw.isNotEmpty) {
      return Image.network(
        AppConfig.resolveUrl(raw),
        fit: BoxFit.cover,
        width: 124,
        height: 124,
        errorBuilder: (_, __, ___) => _initials(siswa),
      );
    }
    return _initials(siswa);
  }

  Widget _initials(dynamic siswa) {
    return Container(
      color: AppColors.primary700,
      alignment: Alignment.center,
      child: Text(
        siswa?.inisial ?? 'SJ',
        style: AppFonts.epilogue(size: 32, weight: FontWeight.w800, color: Colors.white),
      ),
    );
  }

  Widget _dataSection() {
    return _section(
      icon: Symbols.badge,
      title: 'Data Pribadi & Akademik',
      subtitle: 'Informasi identitas resmi siswa di lingkungan sekolah.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Nama Lengkap', required: true),
          const SizedBox(height: 6),
          _input(
            controller: _nama,
            hint: 'Masukkan nama lengkap siswa',
            icon: Symbols.person,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
            validator: (v) {
              final val = (v ?? '').trim();
              if (val.isEmpty) return 'Nama lengkap wajib diisi.';
              if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(val)) return 'Nama hanya boleh berisi huruf dan spasi.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _fieldLabel('Nomor Induk Siswa (NIS)'),
          const SizedBox(height: 6),
          _input(
            controller: _nis,
            hint: 'Contoh: 20241001',
            icon: Symbols.pin,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 14),
          _fieldLabel('Kelas Siswa'),
          const SizedBox(height: 6),
          _kelasDropdown(),
          const SizedBox(height: 14),
          _fieldLabel('Jenis Kelamin'),
          const SizedBox(height: 6),
          _genderCards(),
        ],
      ),
    );
  }

  Widget _kontakSection() {
    return _section(
      icon: Symbols.call,
      title: 'Informasi Kontak',
      subtitle: 'Digunakan untuk notifikasi pembelajaran dan pemulihan akun.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Alamat Email', required: true),
          const SizedBox(height: 6),
          _input(
            controller: _email,
            hint: 'nama@siswa.sekolah.id',
            icon: Symbols.mail,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final val = (v ?? '').trim();
              if (val.isEmpty) return 'Email wajib diisi.';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(val)) return 'Format email tidak valid.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _fieldLabel('Nomor WhatsApp / Telepon'),
          const SizedBox(height: 6),
          _input(
            controller: _telpon,
            hint: 'Contoh: 081234567890',
            icon: Symbols.phone_iphone,
            keyboardType: TextInputType.phone,
            maxLength: 16,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }

  Widget _passwordSection() {
    return _section(
      icon: Symbols.lock,
      title: 'Ubah Kata Sandi (Opsional)',
      subtitle: 'Kosongkan jika Anda tidak bermaksud mengganti kata sandi akun.',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Opsional',
          style: AppFonts.manrope(size: 12, weight: FontWeight.w700, color: const Color(0xFF4B5563)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Kata Sandi Baru'),
          const SizedBox(height: 6),
          _input(
            controller: _password,
            hint: 'Minimal 6 karakter',
            icon: Symbols.lock_reset,
            obscure: _obscure1,
            suffix: IconButton(
              icon: Icon(_obscure1 ? Symbols.visibility : Symbols.visibility_off, size: 18, color: AppColors.gray500),
              onPressed: () => setState(() => _obscure1 = !_obscure1),
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Ulangi Kata Sandi Baru'),
          const SizedBox(height: 6),
          _input(
            controller: _password2,
            hint: 'Ulangi kata sandi di samping',
            icon: Symbols.lock_clock,
            obscure: _obscure2,
            suffix: IconButton(
              icon: Icon(_obscure2 ? Symbols.visibility : Symbols.visibility_off, size: 18, color: AppColors.gray500),
              onPressed: () => setState(() => _obscure2 = !_obscure2),
            ),
            validator: (v) {
              if ((v ?? '').isEmpty && _password.text.isEmpty) return null;
              if (v != _password.text) return 'Konfirmasi kata sandi tidak cocok.';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: AppColors.primary600),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppFonts.epilogue(size: 15, weight: FontWeight.w800)),
                    Text(
                      subtitle,
                      style: AppFonts.manrope(size: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppFonts.manrope(
            size: 11,
            weight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: 0.8,
          ),
        ),
        if (required)
          Text(' *', style: AppFonts.manrope(size: 11, weight: FontWeight.w800, color: AppColors.error)),
      ],
    );
  }

  Widget _input({
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: (_) => setState(() {}),
      style: AppFonts.manrope(size: 14),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: AppFonts.manrope(size: 14, color: AppColors.gray500),
        prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.gray400),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gray200.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
        ),
      ),
    );
  }

  Widget _kelasDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _kelas,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        prefixIcon: const Icon(Symbols.school, size: 20, color: AppColors.gray400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gray200.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
        ),
      ),
      hint: Text('Pilih Kelas', style: AppFonts.manrope(size: 14, color: AppColors.gray500)),
      items: _kelasOptions
          .map((k) => DropdownMenuItem(value: k, child: Text(k, style: AppFonts.manrope(size: 14))))
          .toList(),
      onChanged: (v) => setState(() => _kelas = v),
    );
  }

  Widget _genderCards() {
    Widget card(String value, String title, String subtitle, IconData icon, Color bg, Color fg) {
      final selected = _jenisKelamin == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _jenisKelamin = value),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryFixed.withValues(alpha: 0.5) : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary600 : AppColors.gray200.withValues(alpha: 0.8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 18, color: fg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppFonts.manrope(size: 13, weight: FontWeight.w800)),
                      Text(subtitle, style: AppFonts.manrope(size: 11, color: AppColors.gray500)),
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
        card('L', 'Laki-laki', 'Siswa (L)', Symbols.male, const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
        const SizedBox(width: 12),
        card('P', 'Perempuan', 'Siswi (P)', Symbols.female, AppColors.pink100, const Color(0xFFBE185D)),
      ],
    );
  }

  Widget _actions() {
    return Column(
      children: [
        SjButton(
          label: 'Simpan Perubahan',
          icon: Symbols.save,
          loading: _saving,
          radius: 12,
          onPressed: _saving ? null : _save,
        ),
        const SizedBox(height: 10),
        SjButton(
          label: 'Batal & Kembali',
          icon: Symbols.close,
          backgroundColor: AppColors.gray100,
          foregroundColor: AppColors.onSurfaceVariant,
          radius: 12,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
