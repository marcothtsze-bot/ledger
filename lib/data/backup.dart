import 'dart:convert';

import '../models/account.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../models/txn.dart';
import 'ledger_repository.dart';

/// Backup format version, so a future import can migrate older files.
const int kBackupVersion = 1;

/// Serialises the full [LedgerSnapshot] to a portable, pretty-printed JSON
/// string the user can copy out / save. Reuses each model's `toMap`.
String exportBackupJson(LedgerSnapshot s) {
  final data = <String, Object?>{
    'app': 'ledger',
    'version': kBackupVersion,
    'accounts': s.accounts.map((a) => a.toMap()).toList(),
    'transactions': s.transactions.map((t) => t.toMap()).toList(),
    'recurring': s.recurring.map((r) => r.toMap()).toList(),
    'categories': s.categories.map((c) => c.toMap()).toList(),
    'budgets': s.budgets,
    'incomeMonth': s.incomeMonth,
    'expenseMonth': s.expenseMonth,
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

/// Parses a backup JSON string back into a [LedgerSnapshot]. Throws a
/// [FormatException] if the text isn't a valid Ledger backup.
LedgerSnapshot importBackupJson(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    throw const FormatException('That text is not valid JSON.');
  }
  if (decoded is! Map || decoded['app'] != 'ledger') {
    throw const FormatException('That file is not a Ledger backup.');
  }

  Map<String, Object?> asMap(Object? e) => Map<String, Object?>.from(e as Map);
  List<T> asList<T>(Object? v, T Function(Map<String, Object?>) f) =>
      ((v as List?) ?? const []).map((e) => f(asMap(e))).toList();

  final budgets = <String, double>{};
  final rawBudgets = decoded['budgets'];
  if (rawBudgets is Map) {
    rawBudgets.forEach((k, v) => budgets['$k'] = (v as num).toDouble());
  }

  return LedgerSnapshot(
    accounts: asList(decoded['accounts'], Account.fromMap),
    transactions: asList(decoded['transactions'], Txn.fromMap),
    recurring: asList(decoded['recurring'], Recurring.fromMap),
    categories: asList(decoded['categories'], Category.fromMap),
    budgets: budgets,
    incomeMonth: (decoded['incomeMonth'] as num?)?.toDouble() ?? 0,
    expenseMonth: (decoded['expenseMonth'] as num?)?.toDouble() ?? 0,
  );
}
