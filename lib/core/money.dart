/// Money and number formatting.
///
/// Pure Dart — no Flutter imports — so every formatting rule is unit-testable
/// and the domain layer never depends on the UI framework.
library;

/// Groups an integer with thousands separators, e.g. `1234567` -> `"1,234,567"`.
String groupThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Mirrors the prototype `fmt`: absolute value, rounded, thousands-grouped.
String fmtAmount(num value) => groupThousands(value.round());

/// `HK$1,234` — the app's single currency presentation.
String hk(num value) => 'HK\$${fmtAmount(value)}';

/// Signed `HK$` using the prototype's minus glyph (U+2212) for negatives.
String signedHk(num value) => '${value < 0 ? '−' : ''}${hk(value)}';

/// Parses keypad / text input into a double, matching JS `parseFloat(x || '0')`.
double parseAmount(String? raw) => double.tryParse((raw ?? '').trim()) ?? 0;
