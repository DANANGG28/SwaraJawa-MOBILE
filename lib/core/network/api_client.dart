import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

typedef UnauthCallback = void Function();

/// Klien HTTP terpusat (dio) dengan token Sanctum otomatis.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.instance.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await TokenStorage.instance.clear();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false),
      );
    }
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;

  UnauthCallback? onUnauthorized;

  Dio get dio => _dio;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _guard(() => _dio.get(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    return _guard(() => _dio.post(path, data: data, queryParameters: query));
  }

  Future<Map<String, dynamic>> putJson(String path, {Object? data}) async {
    return _guard(() => _dio.put(path, data: data));
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    return _guard(() => _dio.delete(path));
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required FormData formData,
  }) async {
    return _guard(() => _dio.post(path, data: formData));
  }

  Future<Map<String, dynamic>> _guard(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final res = await request();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'data': data};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }
}
