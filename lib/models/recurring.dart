import 'enums.dart';

/// A recurring commitment: either a subscription or an installment plan.
///
/// For installments, [amount] is the per-month figure, [total] the number of
/// months, and [paid] how many have been paid so far.
class Recurring {
  final String id;
  final String name;
  final double amount;
  final String freq; // 'Monthly' | 'Weekly' | 'Installment'
  final String next; // e.g. 'Jun 24'
  final String catId;
  final RecurringKind kind;
  final int? total;
  final int? paid;

  const Recurring({
    required this.id,
    required this.name,
    required this.amount,
    required this.freq,
    required this.next,
    required this.catId,
    required this.kind,
    this.total,
    this.paid,
  });

  Recurring copyWith({
    String? name,
    double? amount,
    String? freq,
    String? next,
    String? catId,
    RecurringKind? kind,
    int? total,
    int? paid,
  }) {
    return Recurring(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      freq: freq ?? this.freq,
      next: next ?? this.next,
      catId: catId ?? this.catId,
      kind: kind ?? this.kind,
      total: total ?? this.total,
      paid: paid ?? this.paid,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'freq': freq,
    'next': next,
    'catId': catId,
    'kind': kind.name,
    'total': total,
    'paid': paid,
  };

  factory Recurring.fromMap(Map<String, Object?> m) => Recurring(
    id: m['id'] as String,
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
    freq: m['freq'] as String,
    next: m['next'] as String,
    catId: m['catId'] as String,
    kind: enumByName(RecurringKind.values, m['kind'], RecurringKind.sub),
    total: (m['total'] as num?)?.toInt(),
    paid: (m['paid'] as num?)?.toInt(),
  );
}
