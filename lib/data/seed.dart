import '../core/statement.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/enums.dart';
import '../models/recurring.dart';
import '../models/txn.dart';

/// Initial sample data, transcribed from the design prototype. Used to seed the
/// on-device database the first time the app runs.

/// Seeded month-to-date totals (the prototype tracks these as running counters).
const kSeedIncomeMonth = 24100.0;
const kSeedExpenseMonth = 18700.0;

/// The fixed category set (icons are Material Symbols Rounded ligatures).
const List<Category> kCategories = [
  Category(id: 'dining', name: 'Dining', color: '#ff7a6b', icon: 'restaurant'),
  Category(
    id: 'groceries',
    name: 'Groceries',
    color: '#f0a23a',
    icon: 'shopping_cart',
  ),
  Category(id: 'coffee', name: 'Coffee', color: '#d8a25e', icon: 'local_cafe'),
  Category(
    id: 'transport',
    name: 'Transport',
    color: '#5b8cff',
    icon: 'directions_bus',
  ),
  Category(
    id: 'fuel',
    name: 'Fuel',
    color: '#6f8cff',
    icon: 'local_gas_station',
  ),
  Category(
    id: 'shopping',
    name: 'Shopping',
    color: '#f472b6',
    icon: 'shopping_bag',
  ),
  Category(id: 'rent', name: 'Rent', color: '#b69bff', icon: 'home'),
  Category(id: 'utilities', name: 'Utilities', color: '#38bdf8', icon: 'bolt'),
  Category(id: 'phone', name: 'Phone & net', color: '#22d3ee', icon: 'wifi'),
  Category(
    id: 'subs',
    name: 'Subscriptions',
    color: '#facc15',
    icon: 'subscriptions',
  ),
  Category(id: 'fun', name: 'Entertainment', color: '#c084fc', icon: 'movie'),
  Category(id: 'travel', name: 'Travel', color: '#2dd4bf', icon: 'flight'),
  Category(id: 'health', name: 'Health', color: '#fb7185', icon: 'ecg_heart'),
  Category(
    id: 'fitness',
    name: 'Fitness',
    color: '#fb923c',
    icon: 'fitness_center',
  ),
  Category(
    id: 'education',
    name: 'Education',
    color: '#60a5fa',
    icon: 'school',
  ),
  Category(id: 'gifts', name: 'Gifts', color: '#f9a8d4', icon: 'redeem'),
  Category(id: 'pets', name: 'Pets', color: '#a3e635', icon: 'pets'),
  Category(id: 'kids', name: 'Kids', color: '#fcd34d', icon: 'child_care'),
  Category(id: 'savings', name: 'Savings', color: '#34d399', icon: 'savings'),
  Category(id: 'salary', name: 'Salary', color: '#3ad29f', icon: 'payments'),
  Category(id: 'payment', name: 'Payment', color: '#9aa6a1', icon: 'payments'),
];

List<Account> seedAccounts() => [
  const Account(
    id: 'hsbc',
    name: 'HSBC One',
    sub: 'Debit · HKD',
    letter: 'H',
    color: '#3ad29f',
    bg: '#1f3a32',
    balance: 52100,
    nature: AccountNature.asset,
    group: 'cashbank',
    pinned: true,
  ),
  const Account(
    id: 'citi',
    name: 'Standard Chartered',
    sub: 'Credit · HKD',
    letter: 'S',
    color: '#2fae9a',
    bg: '#16302b',
    balance: -8420,
    nature: AccountNature.liability,
    group: 'credit',
    creditLimit: 80000,
    minPayment: 420,
    statementDay: 5,
    dueDay: 25,
    statementBalance: 6420,
    pinned: true,
  ),
  const Account(
    id: 'wise',
    name: 'Wise',
    sub: 'USD · multi-currency',
    letter: 'W',
    color: '#5b8cff',
    bg: '#1f2c3f',
    currency: 'USD',
    balance: 9680,
    nature: AccountNature.asset,
    group: 'cashbank',
    note: '≈ FX 7.81',
  ),
  const Account(
    id: 'cash',
    name: 'Cash wallet',
    sub: 'Cash · HKD',
    letter: '\$',
    color: '#f0a23a',
    bg: '#2d2a1f',
    balance: 2150,
    nature: AccountNature.asset,
    group: 'cashbank',
  ),
  const Account(
    id: 'ib',
    name: 'Interactive Brokers',
    sub: 'AAPL · VOO · BTC · ETH',
    letter: 'IB',
    color: '#5b8cff',
    bg: '#1f2c3f',
    balance: 218400,
    nature: AccountNature.asset,
    group: 'invest',
    note: '▲ 1.2% today',
  ),
  const Account(
    id: 'prop',
    name: 'Property',
    sub: 'Manual asset · HKD',
    letter: 'P',
    color: '#2dd4bf',
    bg: '#1f322e',
    balance: 208390,
    nature: AccountNature.asset,
    group: 'invest',
    note: 'valued Jun',
  ),
];

List<Txn> seedTransactions() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  return [
    Txn(
      id: 1,
      type: TxnType.expense,
      amount: 268,
      payee: 'Tsui Wah',
      catId: 'dining',
      acctId: 'hsbc',
      date: today,
    ),
    Txn(
      id: 2,
      type: TxnType.expense,
      amount: 32,
      payee: 'MTR',
      catId: 'transport',
      acctId: 'cash',
      date: today,
    ),
    Txn(
      id: 3,
      type: TxnType.expense,
      amount: 375,
      payee: 'Amazon US',
      catId: 'shopping',
      acctId: 'citi',
      date: today,
      foreign: 'US\$48.00 @ 7.81',
    ),
    Txn(
      id: 4,
      type: TxnType.income,
      amount: 24100,
      payee: 'Monthly salary',
      catId: 'salary',
      acctId: 'hsbc',
      date: yesterday,
    ),
    Txn(
      id: 5,
      type: TxnType.expense,
      amount: 642,
      payee: 'ParknShop',
      catId: 'groceries',
      acctId: 'hsbc',
      date: yesterday,
    ),
  ];
}

List<Recurring> seedRecurring() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Recurring sub({
    required String id,
    required String name,
    required double amount,
    required String icon,
    required String color,
    required String catId,
    required int inDays,
  }) {
    final nd = today.add(Duration(days: inDays));
    return Recurring(
      id: id,
      name: name,
      amount: amount,
      freq: 'Monthly',
      next: '${monthAbbrev(nd.month)} ${nd.day}',
      catId: catId,
      kind: RecurringKind.sub,
      icon: icon,
      color: color,
      accountId: 'hsbc',
      nextDate: nd,
    );
  }

  return [
    // Netflix is due today so the Upcoming "Due" state is visible on first run.
    sub(id: 'r1', name: 'Netflix', amount: 78, icon: 'movie', color: '#e50914', catId: 'subs', inDays: 0),
    sub(id: 'r2', name: 'Spotify', amount: 58, icon: 'music_note', color: '#1db954', catId: 'subs', inDays: 1),
    sub(id: 'r3', name: 'iCloud', amount: 78, icon: 'cloud', color: '#38bdf8', catId: 'subs', inDays: 6),
    sub(id: 'r4', name: 'Gym', amount: 499, icon: 'fitness_center', color: '#fb923c', catId: 'health', inDays: 5),
  ];
}
