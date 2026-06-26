import 'enums.dart';

/// A single transaction. [amount] is always positive; the sign shown in the UI
/// derives from [type]. [date] is when it happened and drives the Activity day
/// grouping. ([foreign] doubles as a small note slot, e.g. an FX line or an
/// "Installment 1 of 6" marker.)
class Txn {
  final int id;
  final TxnType type;
  final double amount;
  final String payee;
  final String catId;
  final String acctId;
  final DateTime date;
  final String? foreign;
  final String? toAcctId; // transfer destination account (transfers only)

  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.payee,
    required this.catId,
    required this.acctId,
    required this.date,
    this.foreign,
    this.toAcctId,
  });

  Txn copyWith({
    TxnType? type,
    double? amount,
    String? payee,
    String? catId,
    String? acctId,
    DateTime? date,
    String? foreign,
    String? toAcctId,
  }) {
    return Txn(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      payee: payee ?? this.payee,
      catId: catId ?? this.catId,
      acctId: acctId ?? this.acctId,
      date: date ?? this.date,
      foreign: foreign ?? this.foreign,
      toAcctId: toAcctId ?? this.toAcctId,
    );
  }

  // The date is stored as ISO-8601 text in the existing `day` column, so no
  // schema migration is needed. Legacy label rows fall back to a fixed date.
  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'payee': payee,
    'catId': catId,
    'acctId': acctId,
    'day': date.toIso8601String(),
    'foreign': foreign,
    'toAcctId': toAcctId,
  };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
    id: (m['id'] as num).toInt(),
    type: enumByName(TxnType.values, m['type'], TxnType.expense),
    amount: (m['amount'] as num).toDouble(),
    payee: m['payee'] as String,
    catId: m['catId'] as String,
    acctId: m['acctId'] as String,
    date: DateTime.tryParse(m['day'] as String? ?? '') ?? DateTime(2026, 6, 26),
    foreign: m['foreign'] as String?,
    toAcctId: m['toAcctId'] as String?,
  );
}
