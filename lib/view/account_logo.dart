import '../models/account.dart';

/// Returns the bundled brand-logo asset for an account by matching its name to
/// a known bank, or null when there's no logo (the avatar then falls back to a
/// semantic type icon).
String? accountLogoAsset(Account a) {
  final n = a.name.toLowerCase();
  if (n.contains('hsbc')) return 'assets/logos/hsbc.png';
  if (n.contains('standard chartered') || n.contains('stanchart')) {
    return 'assets/logos/standard_chartered.png';
  }
  if (n.contains('wise')) return 'assets/logos/wise.png';
  if (n.contains('interactive brokers') || n.contains('ibkr')) {
    return 'assets/logos/ibkr.png';
  }
  return null;
}
