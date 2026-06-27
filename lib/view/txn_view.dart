import 'package:flutter/widgets.dart';

import '../core/money.dart';
import '../core/statement.dart';
import '../models/enums.dart';
import '../models/txn.dart';
import '../state/ledger_state.dart';
import '../theme/hex_color.dart';
import '../theme/tokens.dart';

/// Flattened, display-ready view of a transaction row — the Flutter equivalent
/// of the prototype's `txView`. Keeps presentation logic in one tested place.
class TxnRowData {
  final String payee;
  final String sub;
  final String letter;
  final String amountText;
  final String date; // e.g. '26 Jun 2026' — for reconciling against a statement
  final Color iconBg;
  final Color iconFg;
  final Color amountColor;

  const TxnRowData({
    required this.payee,
    required this.sub,
    required this.letter,
    required this.amountText,
    required this.date,
    required this.iconBg,
    required this.iconFg,
    required this.amountColor,
  });
}

TxnRowData txnRowData(LedgerState state, Txn t) {
  final c = state.categoryById(t.catId);
  final a = state.accountById(t.acctId);
  final sign = t.type == TxnType.income ? '+' : '−';
  final foreign = t.foreign != null ? ' · ${t.foreign}' : '';
  return TxnRowData(
    payee: t.payee,
    letter: (t.payee.isEmpty ? '?' : t.payee.substring(0, 1)).toUpperCase(),
    sub: '${c.name} · ${a?.name ?? ''}$foreign',
    amountText: '$sign${fmtAmount(t.amount)}',
    date: compactDate(t.date),
    iconFg: hexColor(c.color),
    iconBg: hexColor('${c.color}29'),
    amountColor: t.type == TxnType.income ? AppColors.brand : AppColors.text,
  );
}
