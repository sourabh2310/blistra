import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/accent_palette.dart';

void main() {
  test('all palettes preserve Inter body text and Fraunces headings', () {
    for (final palette in AccentPalette.values) {
      for (final theme in [AppTheme.light(palette), AppTheme.dark(palette)]) {
        for (final text in [theme.textTheme, theme.primaryTextTheme]) {
          expect(text.bodyLarge?.fontFamily, 'Inter');
          expect(text.bodyMedium?.fontFamily, 'Inter');
          expect(text.bodySmall?.fontFamily, 'Inter');
          expect(text.titleMedium?.fontFamily, 'Inter');
          expect(text.labelLarge?.fontFamily, 'Inter');
        }
        expect(theme.textTheme.headlineLarge?.fontFamily, 'Fraunces');
        expect(theme.textTheme.headlineMedium?.fontFamily, 'Fraunces');
        expect(theme.textTheme.headlineSmall?.fontFamily, 'Fraunces');
        expect(theme.textTheme.titleLarge?.fontFamily, 'Fraunces');
        expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Fraunces');
      }
    }
  });
}
