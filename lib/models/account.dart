import '../core/fx.dart';
import 'enums.dart';

/// Sentinel marking "argument not provided" so [Account.copyWith] can tell an
/// omitted `icon` apart from an explicit `icon: null` (clear back to Auto).
const Object _undefined = Object();

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
  final String currency; // ISO code, e.g. 'HKD', 'USD', 'JPY'
  final double? fxRate; // base-currency value of 1 unit; null = use the default
  final double balance; // negative for liabilities (credit owed, loans)
  final AccountNature nature;
  final String? group; // 'cashbank' | 'credit' | 'invest'
  final String? note;
  final String? icon; // user-chosen Material Symbol ligature; null = auto
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
    this.currency = 'HKD',
    this.fxRate,
    required this.balance,
    required this.nature,
    this.group,
    this.note,
    this.icon,
    this.creditLimit,
    this.minPayment,
    this.statementDay,
    this.dueDay,
    this.statementBalance,
    this.pinned = false,
  });

  bool get isLiability => nature == AccountNature.liability;

  bool get isCreditCard => group == 'credit';

  /// Base-currency ([kBaseCurrency]) value of one unit of this account's
  /// currency: its own [fxRate] when set, otherwise the built-in default. Base
  /// accounts are always 1:1 so they never depend on a rate.
  double get rateToHkd => currency.toUpperCase() == kBaseCurrency
      ? 1.0
      : (fxRate ?? defaultRateToHkd(currency));

  /// This account's [balance] converted into the base currency.
  double get balanceHkd => balance * rateToHkd;

  /// Returns a new Account with the given fields replaced (immutable update).
  Account copyWith({
    String? name,
    String? sub,
    String? letter,
    String? color,
    String? bg,
    String? currency,
    double? fxRate,
    double? balance,
    AccountNature? nature,
    String? group,
    String? note,
    Object? icon = _undefined,
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
      currency: currency ?? this.currency,
      fxRate: fxRate ?? this.fxRate,
      balance: balance ?? this.balance,
      nature: nature ?? this.nature,
      group: group ?? this.group,
      note: note ?? this.note,
      icon: identical(icon, _undefined) ? this.icon : icon as String?,
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
    'currency': currency,
    'fxRate': fxRate,
    'balance': balance,
    'nature': nature.name,
    'grp': group,
    'note': note,
    'icon': icon,
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
    currency: m['currency'] as String? ?? 'HKD',
    fxRate: (m['fxRate'] as num?)?.toDouble(),
    balance: (m['balance'] as num).toDouble(),
    nature: enumByName(AccountNature.values, m['nature'], AccountNature.asset),
    group: m['grp'] as String?,
    note: m['note'] as String?,
    icon: m['icon'] as String?,
    creditLimit: (m['creditLimit'] as num?)?.toDouble(),
    minPayment: (m['minPayment'] as num?)?.toDouble(),
    statementDay: (m['statementDay'] as num?)?.toInt(),
    dueDay: (m['dueDay'] as num?)?.toInt(),
    statementBalance: (m['statementBalance'] as num?)?.toDouble(),
    pinned: ((m['pinned'] as num?)?.toInt() ?? 0) == 1,
  );
}
