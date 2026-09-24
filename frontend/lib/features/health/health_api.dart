/// Typed HTTP client for the backend Health module.
///
/// Reuses the shared [ApiClient] (JSON encoding, JWT header, timeout and
/// ApiErrorResponse decoding) and adds typed CRUD methods plus request inputs.
///
/// All owned-resource endpoints scope every query to the authenticated user on
/// the server, so the client never sends a user id. A 404 on the profile GET
/// simply means no profile exists yet and surfaces as `null`.
library;

import '../../core/api/api_exception.dart';
import '../../core/api/api_client.dart';
import 'health_models.dart';

class HealthApi {
  HealthApi(this._client);

  final ApiClient _client;

  // -- Profile --------------------------------------------------------------

  Future<HealthProfile?> getProfile() async {
    try {
      final Object json = await _client.get('/api/v1/health/profile');
      return json is Map<String, dynamic>
          ? HealthProfile.fromJson(json)
          : null;
    } on ApiException catch (error) {
      if (error.isNotFound) {
        return null;
      }
      rethrow;
    }
  }

  Future<HealthProfile> saveProfile(HealthProfileInput input) async {
    final Object json =
        await _client.put('/api/v1/health/profile', body: input.toJson());
    return HealthProfile.fromJson(json as Map<String, dynamic>);
  }

  // -- Measurements -----------------------------------------------------------

  Future<HealthPage<HealthMeasurement>> listMeasurements({
    MeasurementType? type,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final Map<String, String> query = {
      'page': '$page',
      'size': '$size',
      if (type != null) 'type': type.wire,
      if (from != null) 'from': toWireTimestamp(from),
      if (to != null) 'to': toWireTimestamp(to),
    };
    final Object json =
        await _client.get('/api/v1/health/measurements', query: query);
    return HealthPage.fromJson(
        json as Map<String, dynamic>, HealthMeasurement.fromJson);
  }

  Future<HealthMeasurement> createMeasurement(MeasurementInput input) async {
    final Object json =
        await _client.post('/api/v1/health/measurements', body: input.toJson());
    return HealthMeasurement.fromJson(json as Map<String, dynamic>);
  }

  Future<HealthMeasurement> updateMeasurement(
      String id, MeasurementInput input) async {
    final Object json = await _client
        .put('/api/v1/health/measurements/$id', body: input.toJson());
    return HealthMeasurement.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteMeasurement(String id) async =>
      _client.delete('/api/v1/health/measurements/$id');

  // -- Sleep -----------------------------------------------------------------

  Future<HealthPage<HealthSleepRecord>> listSleep({
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final Map<String, String> query = {
      'page': '$page',
      'size': '$size',
      if (from != null) 'from': toWireTimestamp(from),
      if (to != null) 'to': toWireTimestamp(to),
    };
    final Object json = await _client.get('/api/v1/health/sleep', query: query);
    return HealthPage.fromJson(json as Map<String, dynamic>, HealthSleepRecord.fromJson);
  }

  Future<HealthSleepRecord> createSleep(SleepInput input) async {
    final Object json =
        await _client.post('/api/v1/health/sleep', body: input.toJson());
    return HealthSleepRecord.fromJson(json as Map<String, dynamic>);
  }

  Future<HealthSleepRecord> updateSleep(String id, SleepInput input) async {
    final Object json =
        await _client.put('/api/v1/health/sleep/$id', body: input.toJson());
    return HealthSleepRecord.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteSleep(String id) async =>
      _client.delete('/api/v1/health/sleep/$id');

  // -- Activity ----------------------------------------------------------------

  Future<HealthPage<HealthActivity>> listActivities({
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final Map<String, String> query = {
      'page': '$page',
      'size': '$size',
      if (from != null) 'from': toWireTimestamp(from),
      if (to != null) 'to': toWireTimestamp(to),
    };
    final Object json =
        await _client.get('/api/v1/health/activity', query: query);
    return HealthPage.fromJson(json as Map<String, dynamic>, HealthActivity.fromJson);
  }

  Future<HealthActivity> createActivity(ActivityInput input) async {
    final Object json =
        await _client.post('/api/v1/health/activity', body: input.toJson());
    return HealthActivity.fromJson(json as Map<String, dynamic>);
  }

  Future<HealthActivity> updateActivity(String id, ActivityInput input) async {
    final Object json =
        await _client.put('/api/v1/health/activity/$id', body: input.toJson());
    return HealthActivity.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteActivity(String id) async =>
      _client.delete('/api/v1/health/activity/$id');

  // -- Health logs ---------------------------------------------------------------

  Future<HealthPage<HealthLogEntry>> listLogs({
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final Map<String, String> query = {
      'page': '$page',
      'size': '$size',
      if (from != null) 'from': toWireTimestamp(from),
      if (to != null) 'to': toWireTimestamp(to),
    };
    final Object json = await _client.get('/api/v1/health/logs', query: query);
    return HealthPage.fromJson(json as Map<String, dynamic>, HealthLogEntry.fromJson);
  }

  Future<HealthLogEntry> createLog(LogInput input) async {
    final Object json =
        await _client.post('/api/v1/health/logs', body: input.toJson());
    return HealthLogEntry.fromJson(json as Map<String, dynamic>);
  }

  Future<HealthLogEntry> updateLog(String id, LogInput input) async {
    final Object json =
        await _client.put('/api/v1/health/logs/$id', body: input.toJson());
    return HealthLogEntry.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteLog(String id) async =>
      _client.delete('/api/v1/health/logs/$id');

  // -- Health events ---------------------------------------------------------------

  Future<HealthPage<HealthEvent>> listEvents({
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final Map<String, String> query = {
      'page': '$page',
      'size': '$size',
      if (from != null) 'from': toWireTimestamp(from),
      if (to != null) 'to': toWireTimestamp(to),
    };
    final Object json =
        await _client.get('/api/v1/health/events', query: query);
    return HealthPage.fromJson(json as Map<String, dynamic>, HealthEvent.fromJson);
  }

  Future<HealthEvent> createEvent(EventInput input) async {
    final Object json =
        await _client.post('/api/v1/health/events', body: input.toJson());
    return HealthEvent.fromJson(json as Map<String, dynamic>);
  }

  Future<HealthEvent> updateEvent(String id, EventInput input) async {
    final Object json =
        await _client.put('/api/v1/health/events/$id', body: input.toJson());
    return HealthEvent.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String id) async =>
      _client.delete('/api/v1/health/events/$id');

  // -- Appointments ----------------------------------------------------------------

  Future<HealthPage<HealthAppointment>> listAppointments({
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final Map<String, String> query = {
      'page': '$page',
      'size': '$size',
      if (from != null) 'from': toWireTimestamp(from),
      if (to != null) 'to': toWireTimestamp(to),
    };
    final Object json =
        await _client.get('/api/v1/health/appointments', query: query);
    return HealthPage.fromJson(
        json as Map<String, dynamic>, HealthAppointment.fromJson);
  }

  Future<HealthAppointment> createAppointment(AppointmentInput input) async {
    final Object json =
        await _client.post('/api/v1/health/appointments', body: input.toJson());
    return HealthAppointment.fromJson(json as Map<String, dynamic>);
  }

  Future<HealthAppointment> updateAppointment(
      String id, AppointmentInput input) async {
    final Object json = await _client
        .put('/api/v1/health/appointments/$id', body: input.toJson());
    return HealthAppointment.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteAppointment(String id) async =>
      _client.delete('/api/v1/health/appointments/$id');
}