import 'package:test/test.dart';

import 'package:frontend/notifications/services/notification_id.dart';

void main() {
  group('notificationIdFor', () {
    test('deterministic: same input yields same id', () {
      const id = 'abc-123';
      expect(notificationIdFor(id), notificationIdFor(id));
    });

    test('different inputs yield different ids (low collision risk)', () {
      final ids = <int>{};
      for (var i = 0; i < 1000; i++) {
        ids.add(notificationIdFor('reminder-$i'));
      }
      expect(ids.length, 1000);
    });

    test('always positive 31-bit integer (fits Android)', () {
      for (var i = 0; i < 100; i++) {
        final n = notificationIdFor('x$i');
        expect(n > 0, isTrue);
        expect(n < (1 << 31), isTrue);
      }
    });

    test('empty string still produces valid id', () {
      final n = notificationIdFor('');
      expect(n > 0, isTrue);
      expect(n < (1 << 31), isTrue);
    });
  });
}