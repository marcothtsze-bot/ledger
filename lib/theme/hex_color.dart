import 'package:flutter/widgets.dart';

/// Resolves a CSS-style hex string into a Flutter [Color].
///
/// Accepts `#rrggbb`, `rrggbb`, `#rrggbbaa`, or `rrggbbaa` — matching the design
/// tokens, where category tints are the base colour plus an `29` alpha suffix
/// (≈16%). 8-digit CSS order is RRGGBBAA; Flutter wants AARRGGBB.
Color hexColor(String input) {
  var h = input.replaceFirst('#', '').trim();
  if (h.length == 6) {
    h = 'FF$h';
  } else if (h.length == 8) {
    h = h.substring(6, 8) + h.substring(0, 6);
  }
  return Color(int.parse(h, radix: 16));
}
