import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/health/health_models.dart';
import 'package:frontend/features/health/overview_stats.dart';

HealthMeasurement _m({
  required String id,
  required MeasurementType type,
  required DateTime at,
  required double value,
  double? diastolic,
  String unit = 'KG',
}) =>
    HealthMeasurement(
      id: id,
      type: type,
      measuredAt: at,
      value: value,
      valueDiastolic: diastolic,
      unit: unit,
    );

void main() {
  final DateTime day = DateTime(2026, 9, 24, 12, 0);

  List<HealthMeasurement> sample() => [
        _m(
            id: 'w1',
            type: MeasurementType.weight,
            at: DateTime(2026, 9, 24, 8, 0),
            value: 72.4),
        _m(
            id: 'w2',
            type: MeasurementType.weight,
            at: DateTime(2026, 9, 20, 8, 0),
            value: 73.1),
        _m(
            id: 'h1',
            type: MeasurementType.heartRate,
            at: DateTime(2026, 9, 24, 9, 0),
            value: 72,
            unit: 'BPM'),
        _m(
            id: 'h0',
            type: MeasurementType.heartRate,
            at: DateTime(2026, 9, 23, 9, 0),
            value: 68,
            unit: 'BPM'),
      ];

  group('latestPerType', () {
    test('picks newest record per type', () {
      final latest = latestPerType(sample());
      expect(latest[MeasurementType.weight]!.id, 'w1');
      expect(latest[MeasurementType.heartRate]!.id, 'h1');
      expect(latest.containsKey(MeasurementType.temperature), isFalse);
    });

    test('empty input yields empty map (no fake values)', () {
      expect(latestPerType(const []), isEmpty);
    });
  });

  group('todayOnly', () {
    test('keeps same-day records newest first', () {
      final today = todayOnly(sample(), day);
      expect(today.map((m) => m.id), ['h1', 'w1']);
    });

    test('empty day yields empty list', () {
      expect(todayOnly(sample(), DateTime(2026, 1, 1)), isEmpty);
    });
  });

  group('historyFor', () {
    test('filters by type newest first', () {
      final history = historyFor(sample(), MeasurementType.weight);
      expect(history.map((m) => m.id), ['w1', 'w2']);
    });

    test('respects limit', () {
      final history =
          historyFor(sample(), MeasurementType.weight, limit: 1);
      expect(history.map((m) => m.id), ['w1']);
    });
  });

  group('formatValue', () {
    test('renders systolic/diastolic for blood pressure', () {
      final bp = _m(
          id: 'bp',
          type: MeasurementType.bloodPressure,
          at: day,
          value: 120,
          diastolic: 80,
          unit: 'MMHG');
      expect(formatValue(bp), '120 / 80 MMHG');
    });

    test('renders plain value with unit', () {
      final w = _m(
          id: 'w', type: MeasurementType.weight, at: day, value: 72.4);
      expect(formatValue(w), '72.4 KG');
    });
  });

  group('deltaText', () {
    test('weight delta is plain arithmetic', () {
      final all = sample();
      final history = historyFor(all, MeasurementType.weight);
      expect(deltaText(history[0], history[1]), '-0.7 KG vs last reading');
    });

    test('positive delta carries plus sign', () {
      final all = sample();
      final history = historyFor(all, MeasurementType.heartRate);
      expect(deltaText(history[0], history[1]), '+4 BPM vs last reading');
    });

    test('single record yields null (no manufactured trend)', () {
      final temp = _m(
          id: 't',
          type: MeasurementType.temperature,
          at: day,
          value: 36.6,
          unit: 'C');
      expect(deltaText(temp, null), isNull);
    });

    test('blood pressure delta covers both values', () {
      final latest = _m(
          id: 'b1',
          type: MeasurementType.bloodPressure,
          at: day,
          value: 118,
          diastolic: 79,
          unit: 'MMHG');
      final prev = _m(
          id: 'b0',
          type: MeasurementType.bloodPressure,
          at: day.subtract(const Duration(days: 1)),
          value: 120,
          diastolic: 80,
          unit: 'MMHG');
      expect(deltaText(latest, prev), '-2 / -1 MMHG vs last reading');
    });
  });
}
