import 'package:flutter/material.dart';

import '../models/account.dart';
import '../theme/hex_color.dart';
import '../view/account_icon.dart';
import '../view/account_logo.dart';

/// The account avatar. Shows the bank's real logo on a light tile when we have
/// one; otherwise a colour-tinted tile with a semantic type icon (bank, card,
/// wallet, chart, house).
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
    final logo = accountLogoAsset(account);
    if (logo == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hexColor(account.bg),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          accountIcon(account),
          size: size * 0.52,
          color: hexColor(account.color),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Image.asset(
        logo,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Icon(
          accountIcon(account),
          size: size * 0.5,
          color: hexColor(account.color),
        ),
      ),
    );
  }
}
