/// Currency conversion into the app's single base / display currency.
///
/// Pure Dart — no Flutter — so the conversion rules are unit-testable and the
/// domain layer never depends on the UI framework. Every cross-account total in
/// the app (net worth, assets, the month income/expense cards, insights) is
/// expressed in [kBaseCurrency]; per-account rows still show native currency.
library;

/// The one currency every aggregate total is expressed in.
const String kBaseCurrency = 'HKD';

/// Approximate default rates: how many [kBaseCurrency] units one unit of the
/// foreign currency is worth (e.g. `USD: 7.8` ⇒ 1 USD ≈ 7.8 HKD).
///
/// These are sensible starting points only — real rates drift daily, so each
/// account carries its own editable rate that overrides the matching entry.
const Map<String, double> kDefaultRatesToHkd = {
  'HKD': 1.0,
  'USD': 7.8,
  'EUR': 8.4,
  'GBP': 9.9,
  'JPY': 0.052,
  'CNY': 1.08,
  'AUD': 5.1,
  'SGD': 5.8,
};

/// The default base-currency value of one unit of [currency], or `1.0` when the
/// currency is unknown (so an unrecognised code is never silently scaled away).
double defaultRateToHkd(String currency) =>
    kDefaultRatesToHkd[currency.toUpperCase()] ?? 1.0;
