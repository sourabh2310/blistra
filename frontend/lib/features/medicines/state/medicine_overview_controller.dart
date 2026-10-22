/// Per-medicine schedules, recent doses and refills for the Medicines home
/// (7-day adherence, refills due, schedule summary and stock left).
library;

import 'package:flutter/foundation.dart';

import '../data/medicines_api_client.dart';
import '../models/dose_record.dart';
import '../models/medicine.dart';
import '../models/page.dart';
import '../models/refill.dart';
import '../models/schedule.dart';
import '../util/insights.dart';

/// What the home page knows about one medicine beyond the medicine itself.
class MedicineSnapshot {
  const MedicineSnapshot({
    this.schedules = const [],
    this.doses = const [],
    this.refills = const [],
  });

  final List<Schedule> schedules;
  final List<DoseRecord> doses;
  final List<Refill> refills;

  Refill? get latest => latestRefill(refills);
  bool get lowStock => isLowStock(latest);
}

/// Supplementary data: a medicine whose calls fail simply has no snapshot,
/// and the page keeps working from the medicine list and today's slots.
class MedicineOverviewController extends ChangeNotifier {
  MedicineOverviewController(this._api);

  final MedicinesApiClient _api;

  final Map<String, MedicineSnapshot> _snapshots = {};
  String _loadedKey = '';
  bool _loading = false;

  bool get isLoading => _loading;
  MedicineSnapshot? of(String medicineId) => _snapshots[medicineId];

  /// Loads snapshots for [medicines] unless they are unchanged since the last
  /// load; pass [force] to reload anyway (pull to refresh, after a mutation).
  Future<void> load(List<Medicine> medicines, {bool force = false}) async {
    final key = medicineListKey(medicines);
    if (!force && key == _loadedKey) return;
    _loadedKey = key;
    _loading = true;
    notifyListeners();
    final entries = await Future.wait(medicines.map((m) async {
      try {
        final results = await Future.wait([
          _api.listSchedules(m.id),
          _api.listDoses(m.id, page: 0, size: 50),
          _api.listRefills(m.id),
        ]);
        return MapEntry(
          m.id,
          MedicineSnapshot(
            schedules: results[0] as List<Schedule>,
            doses: (results[1] as Page<DoseRecord>).content,
            refills: results[2] as List<Refill>,
          ),
        );
      } catch (_) {
        return null;
      }
    }));
    _snapshots
      ..clear()
      ..addEntries(entries.whereType<MapEntry<String, MedicineSnapshot>>());
    _loading = false;
    notifyListeners();
  }

  /// Taken share of every dose recorded in the last 7 days, or null.
  double? get weekAdherence =>
      adherenceOver(_snapshots.values.expand((s) => s.doses));

  /// Medicines whose latest refill is running low.
  List<String> get lowStockIds => [
        for (final e in _snapshots.entries)
          if (e.value.lowStock) e.key,
      ];
}
