import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/device/device_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('blistra/device_context');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await DeviceContext.refreshTimezone();
  });

  test('uses the native region through DST and updates after travel', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => 'America/Phoenix');
    await DeviceContext.refreshTimezone();
    expect(DeviceContext.currentTimezone(), 'America/Phoenix');
    expect(DeviceContext.hasNativeTimezone, isTrue);
    // Phoenix and Denver can share an offset, but have different DST rules.
    messenger.setMockMethodCallHandler(channel, (_) async => 'America/Denver');
    await DeviceContext.refreshTimezone();
    expect(DeviceContext.currentTimezone(), 'America/Denver');
    messenger.setMockMethodCallHandler(channel, (_) async => 'UTC');
    await DeviceContext.refreshTimezone();
    expect(DeviceContext.currentTimezone(), 'UTC');
  });

  test(
    'missing or invalid platform response is explicitly an estimate',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => 'America/New_York',
      );
      await DeviceContext.refreshTimezone();
      messenger.setMockMethodCallHandler(
        channel,
        (_) => throw PlatformException(code: 'unavailable'),
      );
      await DeviceContext.refreshTimezone();
      expect(DeviceContext.hasNativeTimezone, isFalse);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => 'invalid device value',
      );
      await DeviceContext.refreshTimezone();
      expect(DeviceContext.hasNativeTimezone, isFalse);
    },
  );
}
