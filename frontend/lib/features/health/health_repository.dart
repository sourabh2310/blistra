/// Feature-level repository for the Health module.
///
/// Owns a single [HealthApi] instance and caches the most recent page of each
/// owned resource so the UI can coordinate create/update/delete followed by an
/// automatic refresh. It is a [ChangeNotifier] so multiple screens (home
/// dashboard, per-resource lists) can react to the same data.
library;

import 'package:flutter/foundation.dart';

import 'health_api.dart';
import 'health_models.dart';

class HealthRepository extends ChangeNotifier {
  HealthRepository(this.api);

  final HealthApi api;

  HealthProfile? _profile;
  List<HealthMeasurement> _measurements = const [];
  List<HealthSleepRecord> _sleepRecords = const [];
  List<HealthActivity> _activities = const [];
  List<HealthLogEntry> _logs = const [];
  List<HealthEvent> _events = const [];
  List<HealthAppointment> _appointments = const [];

  HealthProfile? get profile => _profile;
  List<HealthMeasurement> get measurements => _measurements;
  List<HealthSleepRecord> get sleepRecords => _sleepRecords;
  List<HealthActivity> get activities => _activities;
  List<HealthLogEntry> get logs => _logs;
  List<HealthEvent> get events => _events;
  List<HealthAppointment> get appointments => _appointments;

  // -- Profile -----------------------------------------------------------------

  Future<HealthProfile?> loadProfile() async {
    _profile = await api.getProfile();
    notifyListeners();
    return _profile;
  }

  Future<HealthProfile> saveProfile(HealthProfileInput input) async {
    final HealthProfile saved = await api.saveProfile(input);
    _profile = saved;
    notifyListeners();
    return saved;
  }

  // -- Measurements -----------------------------------------------------------------

  Future<List<HealthMeasurement>> loadMeasurements({
    MeasurementType? type,
    DateTime? from,
    DateTime? to,
    int size = 20,
  }) async {
    final HealthPage<HealthMeasurement> page = await api.listMeasurements(
      type: type,
      from: from,
      to: to,
      size: size,
    );
    _measurements = List.unmodifiable(page.content);
    notifyListeners();
    return _measurements;
  }

  Future<HealthMeasurement> createMeasurement(MeasurementInput input) async {
    final HealthMeasurement created = await api.createMeasurement(input);
    await loadMeasurements();
    return created;
  }

  Future<HealthMeasurement> updateMeasurement(
      String id, MeasurementInput input) async {
    final HealthMeasurement updated = await api.updateMeasurement(id, input);
    await loadMeasurements();
    return updated;
  }

  Future<void> deleteMeasurement(String id) async {
    await api.deleteMeasurement(id);
    await loadMeasurements();
  }

  // -- Sleep -----------------------------------------------------------------

  Future<List<HealthSleepRecord>> loadSleepRecords() async {
    final HealthPage<HealthSleepRecord> page = await api.listSleep();
    _sleepRecords = List.unmodifiable(page.content);
    notifyListeners();
    return _sleepRecords;
  }

  Future<HealthSleepRecord> createSleep(SleepInput input) async {
    final HealthSleepRecord created = await api.createSleep(input);
    await loadSleepRecords();
    return created;
  }

  Future<HealthSleepRecord> updateSleep(String id, SleepInput input) async {
    final HealthSleepRecord updated = await api.updateSleep(id, input);
    await loadSleepRecords();
    return updated;
  }

  Future<void> deleteSleep(String id) async {
    await api.deleteSleep(id);
    await loadSleepRecords();
  }

  // -- Activity -----------------------------------------------------------------

  Future<List<HealthActivity>> loadActivities() async {
    final HealthPage<HealthActivity> page = await api.listActivities();
    _activities = List.unmodifiable(page.content);
    notifyListeners();
    return _activities;
  }

  Future<HealthActivity> createActivity(ActivityInput input) async {
    final HealthActivity created = await api.createActivity(input);
    await loadActivities();
    return created;
  }

  Future<HealthActivity> updateActivity(String id, ActivityInput input) async {
    final HealthActivity updated = await api.updateActivity(id, input);
    await loadActivities();
    return updated;
  }

  Future<void> deleteActivity(String id) async {
    await api.deleteActivity(id);
    await loadActivities();
  }

  // -- Health logs -----------------------------------------------------------------

  Future<List<HealthLogEntry>> loadLogs() async {
    final HealthPage<HealthLogEntry> page = await api.listLogs();
    _logs = List.unmodifiable(page.content);
    notifyListeners();
    return _logs;
  }

  Future<HealthLogEntry> createLog(LogInput input) async {
    final HealthLogEntry created = await api.createLog(input);
    await loadLogs();
    return created;
  }

  Future<HealthLogEntry> updateLog(String id, LogInput input) async {
    final HealthLogEntry updated = await api.updateLog(id, input);
    await loadLogs();
    return updated;
  }

  Future<void> deleteLog(String id) async {
    await api.deleteLog(id);
    await loadLogs();
  }

  // -- Health events -----------------------------------------------------------------

  Future<List<HealthEvent>> loadEvents() async {
    final HealthPage<HealthEvent> page = await api.listEvents();
    _events = List.unmodifiable(page.content);
    notifyListeners();
    return _events;
  }

  Future<HealthEvent> createEvent(EventInput input) async {
    final HealthEvent created = await api.createEvent(input);
    await loadEvents();
    return created;
  }

  Future<HealthEvent> updateEvent(String id, EventInput input) async {
    final HealthEvent updated = await api.updateEvent(id, input);
    await loadEvents();
    return updated;
  }

  Future<void> deleteEvent(String id) async {
    await api.deleteEvent(id);
    await loadEvents();
  }

  // -- Appointments -----------------------------------------------------------------

  Future<List<HealthAppointment>> loadAppointments() async {
    final HealthPage<HealthAppointment> page = await api.listAppointments();
    _appointments = List.unmodifiable(page.content);
    notifyListeners();
    return _appointments;
  }

  Future<HealthAppointment> createAppointment(AppointmentInput input) async {
    final HealthAppointment created = await api.createAppointment(input);
    await loadAppointments();
    return created;
  }

  Future<HealthAppointment> updateAppointment(
      String id, AppointmentInput input) async {
    final HealthAppointment updated = await api.updateAppointment(id, input);
    await loadAppointments();
    return updated;
  }

  Future<void> deleteAppointment(String id) async {
    await api.deleteAppointment(id);
    await loadAppointments();
  }
}