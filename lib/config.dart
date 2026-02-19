import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_vcf/interceptors/token_refresh_interceptor.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration - single source of truth
class AppConfig {
  /// Primary environment key in .env: dev | prod
  static String get appEnv => _env('APP_ENV', 'prod');

  /// Optional absolute override for any environment.
  /// Example: API_BASE_URL=https://staging.example.com/api/
  static String get apiBaseUrlOverride => _env('API_BASE_URL');

  /// Environment URLs loaded from .env
  static String get devApiBaseUrlAndroid =>
      _env('DEV_API_BASE_URL_ANDROID', 'http://10.0.2.2:8000/api/');
  static String get devApiBaseUrl =>
      _env('DEV_API_BASE_URL', 'http://localhost:8000/api/');
  static String get prodApiBaseUrl =>
      _env('PROD_API_BASE_URL', 'https://your-server.com/api/');

  /// Optional legacy bool in .env
  static bool get useLocalDev => _envBool('USE_LOCAL_DEV', false);

  static bool get isDev {
    final env = appEnv.trim().toLowerCase();
    return useLocalDev || env == 'dev' || env == 'development';
  }

  /// Auto-select URL with this priority:
  /// API_BASE_URL override > APP_ENV/USE_LOCAL_DEV resolved URL.
  static String get apiBaseUrl {
    final override = apiBaseUrlOverride.trim();
    final rawUrl = override.isNotEmpty
        ? override
        : (isDev ? _devBaseUrlForPlatform : prodApiBaseUrl);

    return _normalizeBaseUrl(rawUrl);
  }

  static String get _devBaseUrlForPlatform {
    if (Platform.isAndroid) {
      return devApiBaseUrlAndroid;
    }
    return devApiBaseUrl;
  }

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw StateError('API base URL is empty. Check your .env values.');
    }
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  static String _env(String key, [String fallback = '']) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  static bool _envBool(String key, bool fallback) {
    final raw = _env(key).toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return fallback;
  }

  /// Creates a Dio instance with baseUrl pre-configured
  /// Includes automatic token refresh interceptor for 401 errors
  static Dio createDio({bool withLogging = false}) {
    final dio = Dio(
      BaseOptions(baseUrl: apiBaseUrl, contentType: 'application/json'),
    );

    // Add token refresh interceptor first (before logging)
    dio.interceptors.add(TokenRefreshInterceptor());

    if (withLogging) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseBody: true,
        ),
      );
    }

    return dio;
  }

  static bool _hasLoggedConfig = false;

  static void logResolvedConfig() {
    if (_hasLoggedConfig || kReleaseMode) return;
    _hasLoggedConfig = true;

    debugPrint('[CONFIG] APP_ENV=$appEnv');
    debugPrint('[CONFIG] USE_LOCAL_DEV=$useLocalDev');
    debugPrint(
      '[CONFIG] API_BASE_URL(.env override)='
      '${apiBaseUrlOverride.isEmpty ? '(none)' : apiBaseUrlOverride}',
    );
    debugPrint('[CONFIG] Resolved API_BASE_URL=$apiBaseUrl');
  }
}
