/// Curated ISO-3166 country dataset for the onboarding country selector.
///
/// Kept in its own file (not inside a widget) so the selector stays small.
/// UI displays flag + name; the backend stores the canonical 2-letter code.
library;

class CountryEntry {
  const CountryEntry(this.code, this.name, this.dialCode);

  final String code;
  final String name;
  final String dialCode;

  /// Regional-indicator flag derived from the ISO code (no emoji assets).
  String get flag {
    final upper = code.toUpperCase();
    return String.fromCharCodes(
      upper.codeUnits.map((c) => 0x1F1E6 + (c - 0x41)),
    );
  }
}

/// Case-insensitive substring search over name + code. Empty query returns
/// the full list; always returns a new list.
List<CountryEntry> searchCountries(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List.of(kCountries);
  return kCountries
      .where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase() == q ||
          c.dialCode.replaceAll('+', '').startsWith(q.replaceAll('+', '')))
      .toList();
}

CountryEntry? countryForCode(String? code) {
  if (code == null || code.isEmpty) return null;
  final upper = code.toUpperCase();
  for (final c in kCountries) {
    if (c.code == upper) return c;
  }
  return null;
}

const kCountries = <CountryEntry>[
  CountryEntry('IN', 'India', '+91'),
  CountryEntry('US', 'United States', '+1'),
  CountryEntry('GB', 'United Kingdom', '+44'),
  CountryEntry('CA', 'Canada', '+1'),
  CountryEntry('AU', 'Australia', '+61'),
  CountryEntry('SG', 'Singapore', '+65'),
  CountryEntry('AE', 'United Arab Emirates', '+971'),
  CountryEntry('DE', 'Germany', '+49'),
  CountryEntry('FR', 'France', '+33'),
  CountryEntry('BR', 'Brazil', '+55'),
  CountryEntry('JP', 'Japan', '+81'),
  CountryEntry('AF', 'Afghanistan', '+93'),
  CountryEntry('ZA', 'South Africa', '+27'),
  CountryEntry('AL', 'Albania', '+355'),
  CountryEntry('AR', 'Argentina', '+54'),
  CountryEntry('AT', 'Austria', '+43'),
  CountryEntry('BD', 'Bangladesh', '+880'),
  CountryEntry('BE', 'Belgium', '+32'),
  CountryEntry('BT', 'Bhutan', '+975'),
  CountryEntry('KH', 'Cambodia', '+855'),
  CountryEntry('CL', 'Chile', '+56'),
  CountryEntry('CN', 'China', '+86'),
  CountryEntry('CO', 'Colombia', '+57'),
  CountryEntry('DK', 'Denmark', '+45'),
  CountryEntry('EG', 'Egypt', '+20'),
  CountryEntry('FI', 'Finland', '+358'),
  CountryEntry('GR', 'Greece', '+30'),
  CountryEntry('HK', 'Hong Kong', '+852'),
  CountryEntry('ID', 'Indonesia', '+62'),
  CountryEntry('IE', 'Ireland', '+353'),
  CountryEntry('IL', 'Israel', '+972'),
  CountryEntry('IT', 'Italy', '+39'),
  CountryEntry('KE', 'Kenya', '+254'),
  CountryEntry('MY', 'Malaysia', '+60'),
  CountryEntry('MX', 'Mexico', '+52'),
  CountryEntry('NP', 'Nepal', '+977'),
  CountryEntry('NL', 'Netherlands', '+31'),
  CountryEntry('NZ', 'New Zealand', '+64'),
  CountryEntry('NG', 'Nigeria', '+234'),
  CountryEntry('NO', 'Norway', '+47'),
  CountryEntry('PK', 'Pakistan', '+92'),
  CountryEntry('PH', 'Philippines', '+63'),
  CountryEntry('PL', 'Poland', '+48'),
  CountryEntry('PT', 'Portugal', '+351'),
  CountryEntry('QA', 'Qatar', '+974'),
  CountryEntry('SA', 'Saudi Arabia', '+966'),
  CountryEntry('ES', 'Spain', '+34'),
  CountryEntry('LK', 'Sri Lanka', '+94'),
  CountryEntry('SE', 'Sweden', '+46'),
  CountryEntry('CH', 'Switzerland', '+41'),
  CountryEntry('TH', 'Thailand', '+66'),
  CountryEntry('TR', 'Turkey', '+90'),
  CountryEntry('UA', 'Ukraine', '+380'),
  CountryEntry('VN', 'Vietnam', '+84'),
];
