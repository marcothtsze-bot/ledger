import 'enums.dart';

/// A money account: bank, card, cash, investment, or a manual asset/liability.
///
/// Colours are stored as hex strings (e.g. `#3ad29f`) exactly like the design
/// prototype, so this model has zero Flutter dependency and stays testable. The
/// UI layer resolves the hex into a `Color`.
class Account {
  final String id;
  final String name;
  final String sub;
  final String letter;
  final String color;
  final String bg;
  final double balance; // negative for liabilities (credit owed, loans)
  final AccountNature nature;
  final String? group; // 'cashbank' | 'credit' | 'invest'
  final String? note;
  final double? creditLimit; // credit cards only — drives utilisation
  final double? minPayment;
  final int? statementDay; // credit card statement closing day of month
  final int? dueDay; // credit card payment due day of month
  final double? statementBalance; // amount owed on the current statement
  final bool pinned; // shown on the Home accounts preview

  const Account({
    required this.id,
    required this.name,
    required this.sub,
    required this.letter,
    required this.color,
    required this.bg,
    required this.balance,
    required this.nature,
    this.group,
    this.note,
    this.creditLimit,
    this.minPayment,
    this.statementDay,
    this.dueDay,
    this.statementBalance,
    this.pinned = false,
  });

  bool get isLiability => nature == AccountNature.liability;

  bool get isCreditCard => group == 'credit';

  /// Returns a new Account with the given fields replaced (immutable update).
  Account copyWith({
    String? name,
    String? sub,
    String? letter,
    String? color,
    String? bg,
    double? balance,
    AccountNature? nature,
    String? group,
    String? note,
    double? creditLimit,
    double? minPayment,
    int? statementDay,
    int? dueDay,
    double? statementBalance,
    bool? pinned,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      sub: sub ?? this.sub,
      letter: letter ?? this.letter,
      color: color ?? this.color,
      bg: bg ?? this.bg,
      balance: balance ?? this.balance,
      nature: nature ?? this.nature,
      group: group ?? this.group,
      note: note ?? this.note,
      creditLimit: creditLimit ?? this.creditLimit,
      minPayment: minPayment ?? this.minPayment,
      statementDay: statementDay ?? this.statementDay,
      dueDay: dueDay ?? this.dueDay,
      statementBalance: statementBalance ?? this.statementBalance,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'sub': sub,
    'letter': letter,
    'color': color,
    'bg': bg,
    'balance': balance,
    'nature': nature.name,
    'grp': group,
    'note': note,
    'creditLimit': creditLimit,
    'minPayment': minPayment,
    'statementDay': statementDay,
    'dueDay': dueDay,
    'statementBalance': statementBalance,
    'pinned': pinned ? 1 : 0,
  };

  factory Account.fromMap(Map<String, Object?> m) => Account(
    id: m['id'] as String,
    name: m['name'] as String,
    sub: m['sub'] as String,
    letter: m['letter'] as String,
    color: m['color'] as String,
    bg: m['bg'] as String,
    balance: (m['balance'] as num).toDouble(),
    nature: enumByName(AccountNature.values, m['nature'], AccountNature.asset),
    group: m['grp'] as String?,
    note: m['note'] as String?,
    creditLimit: (m['creditLimit'] as num?)?.toDouble(),
    minPayment: (m['minPayment'] as num?)?.toDouble(),
    statementDay: (m['statementDay'] as num?)?.toInt(),
    dueDay: (m['dueDay'] as num?)?.toInt(),
    statementBalance: (m['statementBalance'] as num?)?.toDouble(),
    pinned: ((m['pinned'] as num?)?.toInt() ?? 0) == 1,
  );
}
