import 'package:flutter/material.dart';

import '../models/account.dart';
import '../theme/hex_color.dart';
import '../theme/icon_catalog.dart';
import '../view/account_icon.dart';
import '../view/account_logo.dart';

/// The account avatar. Precedence: a **user-chosen icon** wins; otherwise the
/// bank's real logo on a light tile when we have one; otherwise a colour-tinted
/// tile with a semantic type icon (bank, card, wallet, chart, house).
class AccountAvatar extends StatelessWidget {
  final Account account;
  final double size;
  final double radius;

  const AccountAvatar({
    super.key,
    required this.account,
    this.size = 34,
    this.radius = 9,
  });

  @override
  Widget build(BuildContext context) {
    // A user-chosen icon (glyph or a picked bank logo) always wins over the
    // name-based logo heuristic.
    final chosen = account.icon;
    if (chosen != null && chosen.isNotEmpty) {
      if (chosen.startsWith('logo:')) {
        final asset = logoAssetForKey(chosen.substring(5));
        // An explicit choice wins deterministically: if the stored logo key is
        // unknown/stale, show a semantic tile rather than the name heuristic.
        return asset != null ? _logoTile(asset) : _tintedTile(accountIcon(account));
      }
      return _tintedTile(iconFor(chosen));
    }

    final logo = accountLogoAsset(account);
    if (logo == null) return _tintedTile(accountIcon(account));
    return _logoTile(logo);
  }

  Widget _logoTile(String asset) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Icon(
        accountIcon(account),
        size: size * 0.5,
        color: hexColor(account.color),
      ),
    ),
  );

  Widget _tintedTile(IconData icon) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: hexColor(account.bg),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(icon, size: size * 0.52, color: hexColor(account.color)),
  );
}
