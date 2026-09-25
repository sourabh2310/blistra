/// Medicines-specific API client for the Blistra backend.
///
/// Handles all medicines endpoints with proper 204 delete support and
/// error mapping to [ApiException] / [NetworkException].
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/api/api_exception.dart';
import '../../../core/config/app_config.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../models/dose_record.dart';
import '../models/page.dart';
import '../models/refill.dart';
import '../models/schedule.dart';
import '../models/today_doses.dart';

class MedicinesApiClient {
  MedicinesApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this._tokenProvider,
    this._onUnauthorized,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _http;
  final String _baseUrl;
  final String Function()? _tokenProvider;
  final Future<void> Function()? _onUnauthorized;

  static const Duration _timeout = Duration(seconds: 20);

  Map<String, String> _headers() => {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
        if (_tokenProvider != null && _tokenProvider().isNotEmpty)
          HttpHeaders.authorizationHeader: 'Bearer ${_tokenProvider()}',
      };

  Uri _uri(String path, {Map<String, String>? query}) {
    final base = Uri.parse(_baseUrl);
    final resolved = base.resolve(path);
    if (query == null || query.isEmpty) {
      return resolved;
    }
    return resolved.replace(queryParameters: {...resolved.queryParameters, ...query});
  }

  Future<Map<String, dynamic>> _sendObject(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    required int expectStatus,
  }) async {
    final response = await _send(method, path, body: body, query: query);
    final Object? decoded = _tryDecode(response.body);
    if (response.statusCode != expectStatus) {
      await _maybeUnauthorized(response.statusCode);
      throw _toApiException(response.statusCode, decoded);
    }
    if (decoded == null) {
      throw ApiException(
        response.statusCode,
        'EMPTY_RESPONSE',
        'Expected a JSON response but received none.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        response.statusCode,
        'MALFORMED_RESPONSE',
        'Expected a JSON object but received ${decoded.runtimeType}.',
      );
    }
    return decoded;
  }

  Future<List<dynamic>> _sendList(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    required int expectStatus,
  }) async {
    final response = await _send(method, path, body: body, query: query);
    final Object? decoded = _tryDecode(response.body);
    if (response.statusCode != expectStatus) {
      await _maybeUnauthorized(response.statusCode);
      throw _toApiException(response.statusCode, decoded);
    }
    if (decoded == null) {
      throw ApiException(
        response.statusCode,
        'EMPTY_RESPONSE',
        'Expected a JSON array but received none.',
      );
    }
    if (decoded is! List<dynamic>) {
      throw ApiException(
        response.statusCode,
        'MALFORMED_RESPONSE',
        'Expected a JSON array but received ${decoded.runtimeType}.',
      );
    }
    return decoded;
  }

  Future<void> _sendVoid(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    required int expectStatus,
  }) async {
    final response = await _send(method, path, body: body, query: query);
    if (response.statusCode != expectStatus) {
      await _maybeUnauthorized(response.statusCode);
      final Object? decoded = _tryDecode(response.body);
      throw _toApiException(response.statusCode, decoded);
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final request = http.Request(method, _uri(path, query: query))
      ..headers.addAll(_headers());
    if (body != null) {
      request.body = jsonEncode(body);
    }
    try {
      final http.StreamedResponse streamed =
          await _http.send(request).timeout(_timeout);
      return await http.Response.fromStream(streamed);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw NetworkException(error);
    }
  }

  static Object? _tryDecode(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> _maybeUnauthorized(int statusCode) async {
    if (statusCode == 401 && _onUnauthorized != null) {
      try {
        await _onUnauthorized();
      } catch (_) {
        // Logout must never crash the failing request.
      }
    }
  }

  static ApiException _toApiException(int statusCode, Object? body) {
    if (body is! Map<String, dynamic>) {
      return ApiException(statusCode, 'HTTP_$statusCode', '');
    }
    final String code = body['code'] as String? ?? 'HTTP_$statusCode';
    final String message = body['message'] as String? ?? '';
    final Map<String, String> fieldErrors = {};
    final Object? errors = body['errors'];
    if (errors is List) {
      for (final Object? element in errors) {
        if (element is Map<String, dynamic>) {
          final String? field = element['field'] as String?;
          final String? errorMessage = element['message'] as String?;
          if (field != null && errorMessage != null) {
            fieldErrors[field] = errorMessage;
          }
        }
      }
    }
    return ApiException(statusCode, code, message, fieldErrors: fieldErrors);
  }

  // ============ Medicines ============

  Future<Page<Medicine>> listMedicines({
    MedicineStatus? status,
    int page = 0,
    int size = 50,
  }) async {
    final data = await _sendObject(
      'GET',
      '/api/v1/medicines',
      query: {
        'page': '$page',
        'size': '$size',
        if (status != null) 'status': status.name.toUpperCase(),
      },
      expectStatus: 200,
    );
    return Page.fromJson(data, Medicine.fromJson);
  }

  /// Expected doses for the user's current local date, expanded server-side
  /// from active medicines and schedules and matched against recorded doses.
  Future<MedicineToday> getTodayDoses({DateTime? date, int? offsetMinutes}) async {
    final data = await _sendObject(
      'GET',
      '/api/v1/medicines/today',
      query: {
        if (date != null)
          'date':
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        if (offsetMinutes != null) 'offsetMinutes': '$offsetMinutes',
      },
      expectStatus: 200,
    );
    return MedicineToday.fromJson(data);
  }

  Future<Medicine> getMedicine(String id) async {
    final data = await _sendObject(
      'GET',
      '/api/v1/medicines/$id',
      expectStatus: 200,
    );
    return Medicine.fromJson(data);
  }

  Future<Medicine> createMedicine(Map<String, dynamic> request) async {
    final data = await _sendObject(
      'POST',
      '/api/v1/medicines',
      body: request,
      expectStatus: 201,
    );
    return Medicine.fromJson(data);
  }

  Future<Medicine> updateMedicine(String id, Map<String, dynamic> request) async {
    final data = await _sendObject(
      'PUT',
      '/api/v1/medicines/$id',
      body: request,
      expectStatus: 200,
    );
    return Medicine.fromJson(data);
  }

  Future<void> archiveMedicine(String id) async {
    await _sendVoid(
      'DELETE',
      '/api/v1/medicines/$id',
      expectStatus: 204,
    );
  }

  // ============ Schedules ============

  Future<List<Schedule>> listSchedules(String medicineId) async {
    final data = await _sendList(
      'GET',
      '/api/v1/medicines/$medicineId/schedules',
      expectStatus: 200,
    );
    return data.map((e) => Schedule.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Schedule> createSchedule(
    String medicineId,
    Map<String, dynamic> request,
  ) async {
    final data = await _sendObject(
      'POST',
      '/api/v1/medicines/$medicineId/schedules',
      body: request,
      expectStatus: 201,
    );
    return Schedule.fromJson(data);
  }

  Future<Schedule> updateSchedule(
    String medicineId,
    String scheduleId,
    Map<String, dynamic> request,
  ) async {
    final data = await _sendObject(
      'PUT',
      '/api/v1/medicines/$medicineId/schedules/$scheduleId',
      body: request,
      expectStatus: 200,
    );
    return Schedule.fromJson(data);
  }

  Future<void> deleteSchedule(String medicineId, String scheduleId) async {
    await _sendVoid(
      'DELETE',
      '/api/v1/medicines/$medicineId/schedules/$scheduleId',
      expectStatus: 204,
    );
  }

  // ============ Doses ============

  Future<Page<DoseRecord>> listDoses(
    String medicineId, {
    int page = 0,
    int size = 50,
  }) async {
    final data = await _sendObject(
      'GET',
      '/api/v1/medicines/$medicineId/doses',
      query: {
        'page': '$page',
        'size': '$size',
      },
      expectStatus: 200,
    );
    return Page.fromJson(data, DoseRecord.fromJson);
  }

  Future<DoseRecord> recordDose(
    String medicineId,
    Map<String, dynamic> request,
  ) async {
    final data = await _sendObject(
      'POST',
      '/api/v1/medicines/$medicineId/doses',
      body: request,
      expectStatus: 201,
    );
    return DoseRecord.fromJson(data);
  }

  Future<DoseRecord> updateDose(
    String medicineId,
    String doseId,
    Map<String, dynamic> request,
  ) async {
    final data = await _sendObject(
      'PUT',
      '/api/v1/medicines/$medicineId/doses/$doseId',
      body: request,
      expectStatus: 200,
    );
    return DoseRecord.fromJson(data);
  }

  Future<void> deleteDose(String medicineId, String doseId) async {
    await _sendVoid(
      'DELETE',
      '/api/v1/medicines/$medicineId/doses/$doseId',
      expectStatus: 204,
    );
  }

  // ============ Refills ============

  Future<List<Refill>> listRefills(String medicineId) async {
    final data = await _sendList(
      'GET',
      '/api/v1/medicines/$medicineId/refills',
      expectStatus: 200,
    );
    return data.map((e) => Refill.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Refill> createRefill(
    String medicineId,
    Map<String, dynamic> request,
  ) async {
    final data = await _sendObject(
      'POST',
      '/api/v1/medicines/$medicineId/refills',
      body: request,
      expectStatus: 201,
    );
    return Refill.fromJson(data);
  }

  Future<Refill> updateRefill(
    String medicineId,
    String refillId,
    Map<String, dynamic> request,
  ) async {
    final data = await _sendObject(
      'PUT',
      '/api/v1/medicines/$medicineId/refills/$refillId',
      body: request,
      expectStatus: 200,
    );
    return Refill.fromJson(data);
  }

  Future<void> deleteRefill(String medicineId, String refillId) async {
    await _sendVoid(
      'DELETE',
      '/api/v1/medicines/$medicineId/refills/$refillId',
      expectStatus: 204,
    );
  }

  void close() => _http.close();
}