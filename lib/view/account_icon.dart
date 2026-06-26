import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/account.dart';

/// Picks a semantic Material Symbol for an account from its type/group, so rows
/// show a bank / card / wallet / chart / house glyph instead of a letter.
IconData accountIcon(Account a) {
  final sub = a.sub.toLowerCase();
  if (sub.contains('loan')) return Symbols.request_quote_rounded;
  if (a.group == 'credit') return Symbols.credit_card_rounded;
  if (a.group == 'invest') {
    if (sub.contains('property') || sub.contains('manual asset')) {
      return Symbols.home_rounded;
    }
    return Symbols.trending_up_rounded;
  }
  if (sub.contains('cash')) return Symbols.account_balance_wallet_rounded;
  if (sub.contains('multi-currency') || sub.contains('fx')) {
    return Symbols.currency_exchange_rounded;
  }
  return Symbols.account_balance_rounded;
}
