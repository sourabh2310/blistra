import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/device/device_context.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/features/auth/country_data.dart';
import 'package:frontend/features/auth/auth_validators.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('device context', () {
    test('derives country from locale without location access', () {
      expect(DeviceContext.countryFromLocale('en-IN'), 'IN');
      expect(DeviceContext.countryFromLocale('en_US'), 'US');
      expect(DeviceContext.countryFromLocale('en'), isNull);
    });

    test('derives V1 unit defaults from country', () {
      expect(DeviceContext.defaultUnitSystemForCountry('IN'), 'METRIC');
      expect(DeviceContext.defaultUnitSystemForCountry('US'), 'IMPERIAL');
      expect(DeviceContext.defaultUnitSystemForCountry(null), 'METRIC');
    });

    test('uses supplied IANA timezone', () {
      expect(
        DeviceContext.resolveTimezone(
          ianaName: 'Europe/London',
          offsetMinutes: 0,
        ),
        'Europe/London',
      );
      expect(DeviceContext.resolveTimezone(offsetMinutes: 330), 'Asia/Kolkata');
    });
  });

  group('country selector', () {
    test('searches display names and stores canonical codes', () {
      expect(searchCountries('India').single.code, 'IN');
      expect(searchCountries('United States').single.code, 'US');
      expect(countryForCode('in')?.name, 'India');
      expect(countryForCode('not-a-country'), isNull);
    });
  });

  group('onboarding validators', () {
    test('validates dates and country codes', () {
      final now = DateTime(2026, 1, 1);
      expect(validateDateOfBirth(DateTime(1998, 10, 23), now: now), isNull);
      expect(validateDateOfBirth(DateTime(2027, 1, 1), now: now), isNotNull);
      expect(validateDateOfBirth(DateTime(1899, 1, 1), now: now), isNotNull);
      expect(validateCountry('IN'), isNull);
      expect(validateCountry('India'), isNotNull);
    });
  });

  group('theme persistence', () {
    test('persists a pre-login choice and restores it', () async {
      final controller = ThemeController();
      await controller.setMode(ThemeMode.dark);
      final restored = ThemeController();
      await restored.load();
      expect(restored.mode, ThemeMode.dark);
    });
  });
}
