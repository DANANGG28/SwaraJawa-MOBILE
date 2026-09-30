import 'package:google_sign_in/google_sign_in.dart';

import '../core/config/app_config.dart';

/// Galat login Google dengan pesan yang siap ditampilkan.
class GoogleAuthException implements Exception {
  GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Pembungkus Google Sign-In native.
///
/// Alur: minta ID token ke Google, lalu tukar ke token Sanctum melalui
/// `AuthService.loginWithGoogle`.
class GoogleAuthService {
  GoogleAuthService();

  Future<void>? _initialization;

  Future<void> _ensureInitialized() {
    return _initialization ??= GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );
  }

  /// Menjalankan proses sign-in interaktif.
  ///
  /// Mengembalikan Google ID token, atau `null` bila pengguna membatalkan.
  /// Melempar [GoogleAuthException] untuk kegagalan lain.
  Future<String?> getIdToken() async {
    if (!AppConfig.isGoogleSignInConfigured) {
      throw GoogleAuthException(
        'Login Google belum dikonfigurasi. Hubungi administrator.',
      );
    }

    try {
      await _ensureInitialized();
    } catch (_) {
      throw GoogleAuthException(
        'Gagal menyiapkan login Google. Periksa konfigurasi aplikasi.',
      );
    }

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw GoogleAuthException(
        'Login Google tidak didukung pada perangkat ini.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw GoogleAuthException(_messageFor(e));
    } catch (_) {
      throw GoogleAuthException('Gagal masuk dengan Google. Silakan coba lagi.');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw GoogleAuthException(
        'Google tidak mengembalikan ID token. Periksa konfigurasi OAuth.',
      );
    }
    return idToken;
  }

  /// Keluar dari sesi Google (dipakai saat logout).
  Future<void> signOut() async {
    try {
      if (!AppConfig.isGoogleSignInConfigured) return;
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Diamkan — logout aplikasi tetap berlanjut.
    }
  }

  String _messageFor(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Antarmuka Google tidak tersedia saat ini. Coba beberapa saat lagi.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Konfigurasi OAuth Google tidak valid. Hubungi administrator.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Layanan Google sedang bermasalah. Coba beberapa saat lagi.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Proses login Google terputus. Silakan coba lagi.';
      case GoogleSignInExceptionCode.userMismatch:
      case GoogleSignInExceptionCode.unknownError:
      case GoogleSignInExceptionCode.canceled:
        return 'Gagal masuk dengan Google. Silakan coba lagi.';
    }
  }
}
