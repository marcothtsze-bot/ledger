import 'enums.dart';

/// Sentinel so [Recurring.copyWith] (and callers that forward through it) can
/// tell an omitted `endDate` apart from an explicit `endDate: null` (clearing a
/// subscription's end back to ongoing).
const Object kKeepEndDate = Object();

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
  final String? icon; // chosen Material Symbol ligature (null = category icon)
  final String? color; // chosen hex tint (null = category colour)
  final String? accountId; // account this is paid from (null = ask on pay)
  final DateTime? nextDate; // real next-due date driving the Due alert
  final DateTime? startDate; // first charge / when the commitment begins
  final DateTime? endDate; // when it stops (null = ongoing); for subscriptions

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
    this.icon,
    this.color,
    this.accountId,
    this.nextDate,
    this.startDate,
    this.endDate,
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
    String? icon,
    String? color,
    String? accountId,
    DateTime? nextDate,
    DateTime? startDate,
    Object? endDate = kKeepEndDate,
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
      icon: icon ?? this.icon,
      color: color ?? this.color,
      accountId: accountId ?? this.accountId,
      nextDate: nextDate ?? this.nextDate,
      startDate: startDate ?? this.startDate,
      endDate: identical(endDate, kKeepEndDate)
          ? this.endDate
          : endDate as DateTime?,
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
    'icon': icon,
    'color': color,
    'accountId': accountId,
    'nextDate': nextDate?.toIso8601String(),
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
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
    icon: m['icon'] as String?,
    color: m['color'] as String?,
    accountId: m['accountId'] as String?,
    nextDate: DateTime.tryParse((m['nextDate'] as String?) ?? ''),
    startDate: DateTime.tryParse((m['startDate'] as String?) ?? ''),
    endDate: DateTime.tryParse((m['endDate'] as String?) ?? ''),
  );
}
