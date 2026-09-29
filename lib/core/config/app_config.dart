/// Konfigurasi global aplikasi Sinau Jowo.
///
/// Base URL dapat di-override saat build:
///   flutter build apk --dart-define=SJ_BASE_URL=http://192.168.1.10:8000/api
class AppConfig {
  static const String appName = 'Sinau Jowo';
  static const String appTagline = 'Platform Pasinaon';

  /// Emulator Android memakai 10.0.2.2 untuk mengakses localhost host.
  static const String baseUrl = String.fromEnvironment(
    'SJ_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

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
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$origin$path';
    return '$origin/$path';
  }
}
