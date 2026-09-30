import 'package:flutter/foundation.dart';

/// Konfigurasi global aplikasi Sinau Jowo.
///
/// Base URL dapat di-override saat build:
///   flutter build apk --dart-define=SJ_BASE_URL=http://192.168.1.10:8000/api
class AppConfig {
  static const String appName = 'Sinau Jowo';
  static const String appTagline = 'Platform Pasinaon';

  static const String _override = String.fromEnvironment('SJ_BASE_URL');

  /// Google OAuth "Web application" client ID, dipakai sebagai `serverClientId`
  /// agar Android mengembalikan `idToken` yang bisa diverifikasi backend.
  ///
  /// Isi saat build:
  ///   flutter build apk --dart-define=SJ_GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const String googleServerClientId =
      String.fromEnvironment('SJ_GOOGLE_SERVER_CLIENT_ID');

  /// Apakah login Google sudah dikonfigurasi (client ID tersedia).
  static bool get isGoogleSignInConfigured => googleServerClientId.isNotEmpty;

  /// Base URL backend.
  ///
  /// - Jika di-override lewat `--dart-define=SJ_BASE_URL=...`, nilai itu dipakai.
  /// - Web (browser) & desktop memakai `localhost`.
  /// - Emulator Android memakai `10.0.2.2` (alias localhost host).
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  /// Origin (tanpa /api) untuk membangun URL aset storage.
  static String get origin {
    final uri = Uri.parse(baseUrl);
    final segments = List<String>.from(uri.pathSegments);
    if (segments.isNotEmpty && segments.last == 'api') {
      segments.removeLast();
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: segments,
    ).toString();
  }

  static String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uri = Uri.parse(path);
      // Aset disimpan di disk `public` Laravel sehingga path-nya berawalan
      // `/storage/`. URL absolut dari backend memakai `APP_URL`, yang bisa
      // ber-host `localhost` (dev) atau domain lain yang tak dijangkau klien.
      // Selalu layani aset dari host API yang sedang dipakai.
      if (_isLoopbackHost(uri.host) || uri.path.startsWith('/storage/')) {
        final base = Uri.parse(origin);
        return uri
            .replace(
              scheme: base.scheme,
              host: base.host,
              port: base.hasPort ? base.port : null,
            )
            .toString();
      }
      return path;
    }
    if (path.startsWith('/')) return '$origin$path';
    return '$origin/$path';
  }

  static bool _isLoopbackHost(String host) {
    const loopback = {'localhost', '127.0.0.1', '0.0.0.0', '::1', '10.0.2.2'};
    return loopback.contains(host);
  }
}
