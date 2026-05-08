import 'package:dio/dio.dart';
import 'package:flutter_vcf/api_service.dart';
import 'package:flutter_vcf/config.dart';

typedef JsonMap = Map<String, dynamic>;

class SalesApi {
  SalesApi([ApiService? api])
    : _api = api ?? ApiService(AppConfig.createDio(withLogging: true));

  final ApiService _api;

  Future<JsonMap> getLabStatistics(String token) async {
    final response = await _requestWithFallback(
      requests: [
        () => _api.getSalesLabStatistics(token),
        () => _api.getSalesLabStatisticsAlt(token),
      ],
    );
    return _extractStatistics(response);
  }

  Future<List<JsonMap>> getLabVehicles(
    String token, {
    bool? includeRejected,
    bool? includeCancel,
  }) async {
    final response = await _requestWithFallback(
      requests: [
        () => _api.getSalesLabVehicles(
          token,
          includeRejected: includeRejected,
          includeCancel: includeCancel,
        ),
        () => _api.getSalesLabVehiclesAlt(
          token,
          includeRejected: includeRejected,
          includeCancel: includeCancel,
        ),
      ],
    );
    return _extractDataList(response);
  }

  Future<JsonMap> getLabDetail(String token, String registrationId) async {
    final response = await _requestWithFallback(
      requests: [
        () => _api.getSalesLabDetail(token, registrationId),
        () => _api.getSalesLabDetailAlt(token, registrationId),
      ],
    );
    return _extractDataMap(response);
  }

  Future<JsonMap> submitLab(String token, JsonMap payload) async {
    return _requestWithFallback(
      requests: [
        () => _api.submitSalesLab(token, payload),
        () => _api.submitSalesLabAlt(token, payload),
      ],
    );
  }

  Future<JsonMap> getLoadingStatistics(String token) async {
    final response = await _requestWithFallback(
      requests: [
        () => _api.getSalesLoadingStatistics(token),
        () => _api.getSalesLoadingStatisticsAlt(token),
      ],
    );
    return _extractStatistics(response);
  }

  Future<List<JsonMap>> getStartLoadingVehicles(
    String token, {
    bool? includeRejected,
    bool? includeCancel,
  }) async {
    final response = await _requestWithFallback(
      requests: [
        () => _api.getSalesStartLoadingVehicles(
          token,
          includeRejected: includeRejected,
          includeCancel: includeCancel,
        ),
        () => _api.getSalesStartLoadingVehiclesAlt(
          token,
          includeRejected: includeRejected,
          includeCancel: includeCancel,
        ),
        () => _api.getSalesStartLoadingVehiclesAlt2(
          token,
          includeRejected: includeRejected,
          includeCancel: includeCancel,
        ),
      ],
    );
    return _extractDataList(response);
  }

  Future<List<JsonMap>> getFinishLoadingVehicles(
    String token, {
    bool? includeRejected,
    bool? includeCancel,
    bool? includeCompleted,
  }) async {
    final response = await _requestWithFallback(
      requests: [
        () => _api.getSalesFinishLoadingVehiclesAlt2(
          token,
          includeRejected: includeRejected,
          includeCancel: includeCancel,
          includeCompleted: includeCompleted,
        ),
        () => _api.getSalesFinishLoadingVehicles(
          token,
          includeRejected: includeRejected,
          includeCancel: includeCancel,
          includeCompleted: includeCompleted,
        ),
        () => _api.getSalesFinishLoadingVehiclesAlt(
          token,
          includeRejected: includeRejected,
          includeCancel: includeCancel,
          includeCompleted: includeCompleted,
        ),
      ],
    );
    return _extractDataList(response);
  }

  Future<JsonMap> getStartLoadingDetail(String token, String registrationId) async {
    final response = await _requestWithFallback(
      requests: [
        () => _api.getSalesStartLoadingDetail(token, registrationId),
        () => _api.getSalesStartLoadingDetailAlt(token, registrationId),
        () => _api.getSalesStartLoadingDetailAlt2(token, registrationId),
      ],
    );
    return _extractDataMap(response);
  }

  Future<JsonMap> getFinishLoadingDetail(String token, String registrationId) async {
    final response = await _requestWithFallback(
      requests: [
        () => _api.getSalesStartLoadingDetail(token, registrationId),
        () => _api.getSalesStartLoadingDetailAlt(token, registrationId),
        () => _api.getSalesStartLoadingDetailAlt2(token, registrationId),
        () => _api.getSalesFinishLoadingDetailAlt2(token, registrationId),
        () => _api.getSalesFinishLoadingDetail(token, registrationId),
        () => _api.getSalesFinishLoadingDetailAlt(token, registrationId),
      ],
    );
    return _extractDataMap(response);
  }

  Future<JsonMap> submitStartLoading(String token, JsonMap payload) {
    return _requestWithFallback(
      requests: [
        () => _api.submitSalesStartLoading(token, payload),
        () => _api.submitSalesStartLoadingAlt(token, payload),
        () => _api.submitSalesStartLoadingAlt2(token, payload),
      ],
    );
  }

  Future<JsonMap> submitFinishLoading(String token, JsonMap payload) {
    return _requestWithFallback(
      requests: [
        () => _api.submitSalesFinishLoadingAlt2(token, payload),
        () => _api.submitSalesFinishLoading(token, payload),
        () => _api.submitSalesFinishLoadingAlt(token, payload),
      ],
    );
  }

  Future<JsonMap> _requestWithFallback({
    required List<Future<dynamic> Function()> requests,
  }) async {
    DioException? lastError;

    for (final request in requests) {
      try {
        final response = await request();
        return _asJsonMap(response);
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNext(error)) {
          rethrow;
        }
      }
    }

    throw Exception(
      'Sales endpoint tidak ditemukan via Retrofit. '
      'Error terakhir: ${lastError?.message ?? 'unknown error'}',
    );
  }

  bool _shouldTryNext(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 404 || statusCode == 405 || statusCode == 501;
  }

  JsonMap _asJsonMap(dynamic value) {
    if (value is JsonMap) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry),
      );
    }
    throw Exception('Unexpected response type: ${value.runtimeType}');
  }

  JsonMap _extractStatistics(JsonMap response) {
    final data = _extractDataMap(response);
    final statistics = data['statistics'];
    if (statistics is JsonMap) {
      return statistics;
    }
    return data;
  }

  JsonMap _extractDataMap(JsonMap response) {
    final data = response['data'];
    if (data is JsonMap) {
      return data;
    }
    return <String, dynamic>{};
  }

  List<JsonMap> _extractDataList(JsonMap response) {
    final data = response['data'];
    if (data is List) {
      return data.whereType<JsonMap>().toList();
    }
    return const <JsonMap>[];
  }
}