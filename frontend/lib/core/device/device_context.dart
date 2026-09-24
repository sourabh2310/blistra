/// Device-derived context for onboarding defaults.
///
/// Keeps device information (locale, timezone, measurement default) separate
/// from account/profile business logic. Never collects precise location,
/// never requests GPS permission.
library;

/// Pure, testable device-context helpers. Widget code resolves the live
/// locale/timezone and delegates here so the mapping rules stay unit-tested.
class DeviceContext {
  /// Resolves an IANA timezone identifier from platform signals.
  ///
  /// Flutter's [DateTime.timeZoneName] yields an abbreviation (e.g. `IST`),
  /// not IANA. When the platform already provides an IANA name (contains
  /// `/`), it is used as-is after validation. Otherwise the UTC offset
  /// disambiguates the common cases; unknown offsets fall back to `UTC`.
  /// Returns the fallback used so callers can report it instead of silently
  /// inventing a zone.
  static String resolveTimezone({
    String? ianaName,
    String? abbreviation,
    int? offsetMinutes,
  }) {
    final candidate = (ianaName ?? '').trim();
    if (_looksLikeIana(candidate)) return candidate;
    final abbr = (abbreviation ?? '').trim().toUpperCase();
    final offset = offsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
    // Exact-offset fast paths for the zones Blistra serves today.
    if (offset == 330) return 'Asia/Kolkata';
    if (offset == 0 && (abbr == 'UTC' || abbr == 'GMT' || abbr.isEmpty)) {
      return 'UTC';
    }
    final mapped = _offsetFallback[offset];
    if (mapped != null) return mapped;
    return 'UTC';
  }

  /// Live device timezone using current clock signals.
  static String currentTimezone() => resolveTimezone(
        abbreviation: DateTime.now().timeZoneName,
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );

  /// Derives a 2-letter ISO country from a locale (language/region).
  ///
  /// Accepts `en-IN`, `en_IN`, `en-IN-u-...` shapes; returns the uppercased
  /// region when it is exactly two letters, else null (caller keeps the
  /// field un-preselected rather than guessing).
  static String? countryFromLocale(String? localeName) {
    if (localeName == null || localeName.isEmpty) return null;
    final normalized = localeName.replaceAll('_', '-');
    final parts = normalized.split('-');
    for (final part in parts.skip(1)) {
      final code = part.trim();
      if (RegExp(r'^[A-Za-z]{2}$').hasMatch(code)) {
        return code.toUpperCase();
      }
    }
    return null;
  }

  /// Sensible V1 unit default: Imperial only for US/LR/MM, Metric elsewhere.
  static String defaultUnitSystemForCountry(String? isoCode) {
    switch ((isoCode ?? '').toUpperCase()) {
      case 'US':
      case 'LR':
      case 'MM':
        return 'IMPERIAL';
      default:
        return 'METRIC';
    }
  }

  static bool _looksLikeIana(String value) {
    if (!value.contains('/')) return false;
    if (value.length > 64) return false;
    return RegExp(r'^[A-Za-z0-9_+\-]+(/[A-Za-z0-9_+\-]+)+$').hasMatch(value);
  }

  static const _offsetFallback = <int, String>{
    -720: 'Pacific/Kiritimati',
    -660: 'Pacific/Honolulu',
    -480: 'America/Los_Angeles',
    -420: 'America/Denver',
    -360: 'America/Chicago',
    -300: 'America/New_York',
    -240: 'America/Halifax',
    -180: 'America/Sao_Paulo',
    -60: 'Atlantic/Azores',
    60: 'Europe/Berlin',
    120: 'Europe/Athens',
    180: 'Asia/Dubai',
    240: 'Asia/Dubai',
    270: 'Asia/Kabul',
    300: 'Asia/Karachi',
    330: 'Asia/Kolkata',
    345: 'Asia/Kathmandu',
    360: 'Asia/Dhaka',
    390: 'Asia/Rangoon',
    420: 'Asia/Bangkok',
    480: 'Asia/Singapore',
    540: 'Asia/Tokyo',
    570: 'Australia/Darwin',
    600: 'Australia/Sydney',
    660: 'Pacific/Noumea',
  };
}
