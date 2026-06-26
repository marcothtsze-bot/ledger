import '../models/account.dart';

/// Bundled brand logos the user can pick explicitly in the account icon picker,
/// and that the name-based [accountLogoAsset] heuristic also matches. Keyed by a
/// stable slug stored on the account as `icon = 'logo:<key>'`.
const Map<String, ({String label, String asset})> kAccountLogos = {
  'hsbc': (label: 'HSBC', asset: 'assets/logos/hsbc.png'),
  'standard_chartered': (
    label: 'StanChart',
    asset: 'assets/logos/standard_chartered.png',
  ),
  'wise': (label: 'Wise', asset: 'assets/logos/wise.png'),
  'ibkr': (label: 'IBKR', asset: 'assets/logos/ibkr.png'),
};

/// The bundled asset path for a logo [key], or null if it isn't a known logo.
String? logoAssetForKey(String key) => kAccountLogos[key]?.asset;

/// Returns the bundled brand-logo asset for an account by matching its name to
/// a known bank, or null when there's no logo (the avatar then falls back to a
/// semantic type icon).
String? accountLogoAsset(Account a) {
  final n = a.name.toLowerCase();
  if (n.contains('hsbc')) return kAccountLogos['hsbc']!.asset;
  if (n.contains('standard chartered') || n.contains('stanchart')) {
    return kAccountLogos['standard_chartered']!.asset;
  }
  if (n.contains('wise')) return kAccountLogos['wise']!.asset;
  if (n.contains('interactive brokers') || n.contains('ibkr')) {
    return kAccountLogos['ibkr']!.asset;
  }
  return null;
}
