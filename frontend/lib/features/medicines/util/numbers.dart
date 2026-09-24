/// Number formatting helpers for the Medicines feature.
library;

/// Renders [value] without a redundant ".0" so whole numbers typed in forms
/// round-trip cleanly ("250" stays "250" instead of becoming "250.0").
String trimNumber(num value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toString();
