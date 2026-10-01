import 'package:dio/dio.dart';

/// Galat terstruktur dari REST API SINAU APP.
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.errors = const <String, List<String>>{},
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>> errors;

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return ApiException('Koneksi ke server timeout. Periksa jaringan Anda.');
      }
      return ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }

    final data = res.data;
    String message = 'Terjadi kesalahan pada server.';
    final errors = <String, List<String>>{};

    if (data is Map) {
      final rawMessage = data['message'];
      if (rawMessage is String && rawMessage.isNotEmpty) {
        message = rawMessage;
      }
      final rawErrors = data['errors'];
      if (rawErrors is Map) {
        rawErrors.forEach((key, value) {
          if (value is List) {
            errors[key.toString()] = value.map((e) => e.toString()).toList();
          } else if (value != null) {
            errors[key.toString()] = [value.toString()];
          }
        });
      }
    }

    if (res.statusCode == 429) {
      message = 'Terlalu banyak permintaan. Silakan tunggu sebentar.';
    }

    return ApiException(message, statusCode: res.statusCode, errors: errors);
  }

  String? firstErrorFor(String field) {
    final list = errors[field];
    if (list != null && list.isNotEmpty) return list.first;
    return null;
  }

  String get firstError {
    if (errors.isNotEmpty) {
      for (final entry in errors.entries) {
        if (entry.value.isNotEmpty) return entry.value.first;
      }
    }
    return message;
  }

  @override
  String toString() => message;
}
