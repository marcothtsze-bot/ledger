import 'dart:math';

import '../core/money.dart';
import '../data/ledger_repository.dart';
import '../data/seed.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/enums.dart';
import '../models/recurring.dart';
import '../models/txn.dart';

/// Which primary screen the bottom tab bar is showing.
enum AppTab { home, accounts, activity, insights }

/// The full-screen overlay layered above the tabs, if any.
enum LedgerOverlay { none, recurring, account }

/// Which slide-up picker is open inside the Add Transaction sheet.
enum ActivePicker { none, account, category, repeat }

/// When the account picker is open, whether we're choosing the "from" or
/// transfer "to" account.
enum PickingSide { from, to }

/// A day-grouped bucket of transactions for the Activity screen.
class ActivityGroup {
  final DateTime date;
  final List<Txn> items;
  final double total; // net: + income, − expense
  const ActivityGroup({
    required this.date,
    required this.items,
    required this.total,
  });
}

const _unknownCategory = Category(
  id: '?',
  name: '—',
  color: '#8a958f',
  icon: 'help',
);

const _accountPalette = [
  '#3ad29f',
  '#5b8cff',
  '#f0a23a',
  '#b69bff',
  '#f472b6',
  '#2dd4bf',
  '#38bdf8',
  '#fb7185',
];

/// Parses a day-of-month string into 1–31, or null if blank/invalid.
int? _parseDay(String s) {
  final n = int.tryParse(s.trim());
  return n?.clamp(1, 31).toInt();
}

/// The complete, immutable application state. Every transition returns a new
/// instance (never mutates), and all the meaningful logic lives here as pure
/// methods so it can be unit-tested without Flutter.
class LedgerState {
  // Navigation / chrome
  final AppTab tab;
  final bool sheetOpen;
  final LedgerOverlay overlay;
  final String overlayAcct; // account id, or '' for none
  final bool acctSheetOpen;
  final String
  payCardId; // credit card whose statement is being paid, '' = none
  final ActivePicker picker;
  final PickingSide picking;

  // Add Transaction draft
  final TxnType txnType;
  final String amount; // keypad-driven string, e.g. '12.50'
  final String payee;
  final bool invalid;
  final String accountId;
  final String toAccountId;
  final String categoryId;
  final RepeatMode repeat;
  final int installMonths;
  final int editingTxnId; // 0 = adding, else the transaction id being edited
  final DateTime txnDate; // date for the drafted transaction

  // Add / Edit Account draft
  final String editingAccountId; // '' = adding, else the id being edited
  final String newName;
  final String newType;
  final String newCurrency;
  final String newBalance;
  final bool newInvalid;
  final String newLimit; // credit card credit limit
  final String newStatementDay; // statement closing day of month
  final String newDueDay; // payment due day of month
  final String newStatementBalance; // amount owed on the current statement

  // Data
  final List<Account> accounts;
  final List<Txn> transactions;
  final List<Recurring> recurring;
  final double incomeMonth;
  final double expenseMonth;

  // Transient
  final String search;
  final String toast; // '' when nothing showing

  const LedgerState({
    required this.tab,
    required this.sheetOpen,
    required this.overlay,
    required this.overlayAcct,
    required this.acctSheetOpen,
    required this.payCardId,
    required this.picker,
    required this.picking,
    required this.txnType,
    required this.amount,
    required this.payee,
    required this.invalid,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.repeat,
    required this.installMonths,
    required this.editingTxnId,
    required this.txnDate,
    required this.editingAccountId,
    required this.newName,
    required this.newType,
    required this.newCurrency,
    required this.newBalance,
    required this.newInvalid,
    required this.newLimit,
    required this.newStatementDay,
    required this.newDueDay,
    required this.newStatementBalance,
    required this.accounts,
    required this.transactions,
    required this.recurring,
    required this.incomeMonth,
    required this.expenseMonth,
    required this.search,
    required this.toast,
  });

  /// Fresh state seeded with the prototype's sample data.
  factory LedgerState.initial() => LedgerState(
    tab: AppTab.home,
    sheetOpen: false,
    overlay: LedgerOverlay.none,
    overlayAcct: '',
    acctSheetOpen: false,
    payCardId: '',
    picker: ActivePicker.none,
    picking: PickingSide.from,
    txnType: TxnType.expense,
    amount: '',
    payee: '',
    invalid: false,
    accountId: 'citi',
    toAccountId: 'hsbc',
    categoryId: 'dining',
    repeat: RepeatMode.off,
    installMonths: 6,
    editingTxnId: 0,
    txnDate: DateTime.now(),
    editingAccountId: '',
    newName: '',
    newType: 'Debit',
    newCurrency: 'HKD',
    newBalance: '',
    newInvalid: false,
    newLimit: '',
    newStatementDay: '',
    newDueDay: '',
    newStatementBalance: '',
    accounts: seedAccounts(),
    transactions: seedTransactions(),
    recurring: seedRecurring(),
    incomeMonth: kSeedIncomeMonth,
    expenseMonth: kSeedExpenseMonth,
    search: '',
    toast: '',
  );

  /// Rehydrates persisted data over the default draft/UI state.
  factory LedgerState.fromSnapshot(LedgerSnapshot s) =>
      LedgerState.initial().copyWith(
        accounts: s.accounts,
        transactions: s.transactions,
        recurring: s.recurring,
        incomeMonth: s.incomeMonth,
        expenseMonth: s.expenseMonth,
      );

  LedgerSnapshot toSnapshot() => LedgerSnapshot(
    accounts: accounts,
    transactions: transactions,
    recurring: recurring,
    incomeMonth: incomeMonth,
    expenseMonth: expenseMonth,
  );

  // ---- Lookups & derivations -------------------------------------------------

  Account? accountById(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Category categoryById(String id) =>
      kCategories.firstWhere((c) => c.id == id, orElse: () => _unknownCategory);

  double get netWorth => accounts.fold(0, (sum, a) => sum + a.balance);

  double get assets =>
      accounts.where((a) => a.balance > 0).fold(0, (sum, a) => sum + a.balance);

  double get liabilities => accounts
      .where((a) => a.balance < 0)
      .fold<double>(0, (sum, a) => sum + a.balance)
      .abs();

  /// Normalised monthly value of all recurring commitments (weekly ×4.33).
  double get recurringMonthly => recurring.fold(
    0,
    (sum, r) => sum + (r.freq == 'Weekly' ? r.amount * 4.33 : r.amount),
  );

  List<Recurring> get subscriptions =>
      recurring.where((r) => r.kind == RecurringKind.sub).toList();

  List<Recurring> get installments =>
      recurring.where((r) => r.kind == RecurringKind.installment).toList();

  bool get isTransfer => txnType == TxnType.transfer;

  /// Per-month figure for the installment preview (0 when no amount yet).
  int get installPerMonth {
    final amt = parseAmount(amount);
    return amt > 0 && installMonths > 0 ? (amt / installMonths).round() : 0;
  }

  int get _nextTxnId =>
      transactions.isEmpty ? 1 : transactions.map((t) => t.id).reduce(max) + 1;

  /// Activity screen, filtered by [search] and grouped by day (order preserved).
  List<ActivityGroup> get activityGroups {
    final q = search.trim().toLowerCase();
    final filtered = transactions.where((t) {
      if (q.isEmpty) return true;
      return t.payee.toLowerCase().contains(q) ||
          categoryById(t.catId).name.toLowerCase().contains(q);
    }).toList();

    final byDay = <int, List<Txn>>{};
    for (final t in filtered) {
      final key = t.date.year * 10000 + t.date.month * 100 + t.date.day;
      (byDay[key] ??= []).add(t);
    }
    final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return keys.map((k) {
      final items = byDay[k]!..sort((a, b) => b.date.compareTo(a.date));
      final total = items.fold<double>(
        0,
        (sum, t) => sum + (t.type == TxnType.income ? t.amount : -t.amount),
      );
      return ActivityGroup(date: items.first.date, items: items, total: total);
    }).toList();
  }

  bool get noSearchResults =>
      search.trim().isNotEmpty && activityGroups.isEmpty;

  // ---- Transitions (pure: return a new LedgerState) --------------------------

  /// Keypad input for the amount field. Guards a single decimal point and at
  /// most two decimal places; backspace trims one char.
  LedgerState pressKey(String key) {
    var a = amount;
    if (key == 'del') {
      a = a.isEmpty ? a : a.substring(0, a.length - 1);
    } else if (key == '.') {
      if (!a.contains('.')) a = '${a.isEmpty ? '0' : a}.';
    } else {
      if (a.contains('.') && a.split('.')[1].length >= 2) return this;
      a = (a == '0' || a.isEmpty) ? key : a + key;
    }
    return copyWith(amount: a, invalid: false);
  }

  /// Commits the drafted transaction. Returns the state unchanged-but-`invalid`
  /// if the amount is not positive. [close] true = Save (close sheet, jump to
  /// Activity); false = "+ another" (keep sheet open, reset for rapid entry).
  LedgerState save({required bool close}) {
    final amt = parseAmount(amount);
    if (!(amt > 0)) return copyWith(invalid: true);
    if (editingTxnId != 0) return _editTxn(amt);

    var per = amt, logged = amt;
    if (repeat == RepeatMode.installment) {
      per = (amt / installMonths).roundToDouble();
      logged = per;
    }
    final pay = payee.trim().isEmpty
        ? categoryById(categoryId).name
        : payee.trim();
    final txId = _nextTxnId;
    final tx = Txn(
      id: txId,
      type: txnType,
      amount: logged,
      payee: pay,
      catId: categoryId,
      acctId: accountId,
      date: txnDate,
      foreign: repeat == RepeatMode.installment
          ? 'Installment 1 of $installMonths'
          : null,
      toAcctId: txnType == TxnType.transfer ? toAccountId : null,
    );

    final newAccounts = accounts.map((a) {
      var b = a.balance;
      if (a.id == accountId) {
        b += (txnType == TxnType.income) ? logged : -logged;
      }
      if (txnType == TxnType.transfer && a.id == toAccountId) b += logged;
      return a.copyWith(balance: b);
    }).toList();

    var inc = incomeMonth, exp = expenseMonth;
    if (txnType == TxnType.income) {
      inc += logged;
    } else if (txnType == TxnType.expense) {
      exp += logged;
    }

    var newRecurring = recurring;
    if (repeat == RepeatMode.weekly || repeat == RepeatMode.monthly) {
      newRecurring = [
        Recurring(
          id: 'u$txId',
          name: pay,
          amount: logged,
          freq: repeat == RepeatMode.monthly ? 'Monthly' : 'Weekly',
          next: 'Jul 21',
          catId: categoryId,
          kind: RecurringKind.sub,
        ),
        ...recurring,
      ];
    } else if (repeat == RepeatMode.installment) {
      newRecurring = [
        Recurring(
          id: 'u$txId',
          name: pay,
          amount: per,
          freq: 'Installment',
          next: 'Jul 21',
          catId: categoryId,
          kind: RecurringKind.installment,
          total: installMonths,
          paid: 1,
        ),
        ...recurring,
      ];
    }

    return copyWith(
      transactions: [tx, ...transactions],
      accounts: newAccounts,
      incomeMonth: inc,
      expenseMonth: exp,
      recurring: newRecurring,
      amount: '',
      payee: '',
      repeat: RepeatMode.off,
      invalid: false,
      sheetOpen: !close,
      tab: close ? AppTab.activity : tab,
      toast: repeat == RepeatMode.installment
          ? 'Installment plan started'
          : 'Transaction saved',
    );
  }

  Txn? _txnById(int id) {
    for (final t in transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Applies an edit to transaction [editingTxnId]: reverses the original's
  /// effect on balances and month totals, then applies the new values.
  LedgerState _editTxn(double amt) {
    final old = _txnById(editingTxnId);
    if (old == null) {
      return copyWith(
        sheetOpen: false,
        editingTxnId: 0,
        amount: '',
        payee: '',
        invalid: false,
      );
    }
    final pay = payee.trim().isEmpty
        ? categoryById(categoryId).name
        : payee.trim();
    final updated = Txn(
      id: old.id,
      type: txnType,
      amount: amt,
      payee: pay,
      catId: categoryId,
      acctId: accountId,
      date: txnDate,
      foreign: old.foreign,
      toAcctId: txnType == TxnType.transfer ? toAccountId : null,
    );

    final newAccounts = accounts.map((a) {
      var b = a.balance;
      if (a.id == old.acctId) {
        b += (old.type == TxnType.income) ? -old.amount : old.amount;
      }
      if (old.type == TxnType.transfer && a.id == old.toAcctId) b -= old.amount;
      if (a.id == accountId) b += (txnType == TxnType.income) ? amt : -amt;
      if (txnType == TxnType.transfer && a.id == toAccountId) b += amt;
      return a.copyWith(balance: b);
    }).toList();

    var inc = incomeMonth, exp = expenseMonth;
    if (old.type == TxnType.income) {
      inc -= old.amount;
    } else if (old.type == TxnType.expense) {
      exp -= old.amount;
    }
    if (txnType == TxnType.income) {
      inc += amt;
    } else if (txnType == TxnType.expense) {
      exp += amt;
    }

    return copyWith(
      transactions: transactions
          .map((t) => t.id == editingTxnId ? updated : t)
          .toList(),
      accounts: newAccounts,
      incomeMonth: inc,
      expenseMonth: exp,
      amount: '',
      payee: '',
      repeat: RepeatMode.off,
      invalid: false,
      editingTxnId: 0,
      sheetOpen: false,
      toast: 'Transaction updated',
    );
  }

  /// Deletes transaction [id], reversing its effect on balances and totals.
  LedgerState deleteTxn(int id) {
    final old = _txnById(id);
    if (old == null) return copyWith(sheetOpen: false, editingTxnId: 0);
    final newAccounts = accounts.map((a) {
      var b = a.balance;
      if (a.id == old.acctId) {
        b += (old.type == TxnType.income) ? -old.amount : old.amount;
      }
      if (old.type == TxnType.transfer && a.id == old.toAcctId) b -= old.amount;
      return a.copyWith(balance: b);
    }).toList();
    var inc = incomeMonth, exp = expenseMonth;
    if (old.type == TxnType.income) {
      inc -= old.amount;
    } else if (old.type == TxnType.expense) {
      exp -= old.amount;
    }
    return copyWith(
      transactions: transactions.where((t) => t.id != id).toList(),
      accounts: newAccounts,
      incomeMonth: inc,
      expenseMonth: exp,
      amount: '',
      payee: '',
      invalid: false,
      editingTxnId: 0,
      sheetOpen: false,
      toast: 'Transaction deleted',
    );
  }

  /// Commits the drafted account — adds a new one, or updates the account being
  /// edited ([editingAccountId]). Returns unchanged-but-`newInvalid` when the
  /// name is blank.
  LedgerState saveAccount() {
    final name = newName.trim();
    if (name.isEmpty) return copyWith(newInvalid: true);

    // Editing an existing account (balance + credit-card statement settings).
    if (editingAccountId.isNotEmpty) {
      final existing = accountById(editingAccountId);
      if (existing == null) return _closeAcctDraft();
      final balAbs = parseAmount(newBalance).abs();
      final updated = existing.copyWith(
        name: name,
        balance: existing.isLiability ? -balAbs : balAbs,
        creditLimit: newLimit.isEmpty
            ? existing.creditLimit
            : parseAmount(newLimit),
        statementDay: newStatementDay.isEmpty
            ? existing.statementDay
            : _parseDay(newStatementDay),
        dueDay: newDueDay.isEmpty ? existing.dueDay : _parseDay(newDueDay),
        statementBalance: newStatementBalance.isEmpty
            ? existing.statementBalance
            : parseAmount(newStatementBalance),
      );
      final next = accounts
          .map((a) => a.id == editingAccountId ? updated : a)
          .toList();
      return _closeAcctDraft().copyWith(
        accounts: next,
        toast: 'Account updated',
      );
    }

    // Adding a new account.
    final isLiab = newType == 'Credit' || newType == 'Loan';
    final group = newType == 'Investment'
        ? 'invest'
        : (isLiab ? 'credit' : 'cashbank');
    final isCredit = group == 'credit';
    final bal = parseAmount(newBalance);
    final balance = isLiab ? -bal.abs() : bal.abs();
    final color = _accountPalette[accounts.length % _accountPalette.length];

    final acct = Account(
      id: 'a${accounts.length}',
      name: name,
      sub: '$newType · $newCurrency',
      letter: name.substring(0, 1).toUpperCase(),
      color: color,
      bg: '${color}29',
      balance: balance,
      nature: isLiab ? AccountNature.liability : AccountNature.asset,
      group: group,
      creditLimit: isCredit && newLimit.isNotEmpty
          ? parseAmount(newLimit)
          : null,
      statementDay: isCredit && newStatementDay.isNotEmpty
          ? _parseDay(newStatementDay)
          : null,
      dueDay: isCredit && newDueDay.isNotEmpty ? _parseDay(newDueDay) : null,
      statementBalance: isCredit && newStatementBalance.isNotEmpty
          ? parseAmount(newStatementBalance)
          : null,
    );

    return _closeAcctDraft().copyWith(
      accounts: [...accounts, acct],
      toast: 'Account added',
    );
  }

  /// Clears the add/edit account draft and closes the sheet.
  LedgerState _closeAcctDraft() => copyWith(
    acctSheetOpen: false,
    editingAccountId: '',
    newName: '',
    newBalance: '',
    newType: 'Debit',
    newCurrency: 'HKD',
    newInvalid: false,
    newLimit: '',
    newStatementDay: '',
    newDueDay: '',
    newStatementBalance: '',
  );

  /// Accounts that can pay a statement (spendable cash/bank assets).
  List<Account> get payableAccounts => accounts
      .where((a) => !a.isLiability && (a.group ?? 'cashbank') == 'cashbank')
      .toList();

  /// Accounts pinned to the Home preview (capped at 3).
  List<Account> get pinnedAccounts =>
      accounts.where((a) => a.pinned).take(3).toList();

  /// Pays the current card's ([payCardId]) statement from [fromId]: debits the
  /// paying account, reduces the card's debt, clears the statement, and logs a
  /// transfer. Net worth is unchanged (assets and liabilities both fall).
  LedgerState payStatement(String fromId) {
    final card = accountById(payCardId);
    final from = accountById(fromId);
    if (card == null || from == null) return copyWith(payCardId: '');
    final amount = card.statementBalance ?? 0;
    if (amount <= 0) return copyWith(payCardId: '');

    final next = accounts.map((a) {
      if (a.id == from.id) return a.copyWith(balance: a.balance - amount);
      if (a.id == card.id) {
        return a.copyWith(balance: a.balance + amount, statementBalance: 0);
      }
      return a;
    }).toList();

    final tx = Txn(
      id: _nextTxnId,
      type: TxnType.transfer,
      amount: amount,
      payee: '${card.name} payment',
      catId: 'payment',
      acctId: from.id,
      date: DateTime.now(),
    );

    return copyWith(
      accounts: next,
      transactions: [tx, ...transactions],
      payCardId: '',
      toast: 'Statement marked paid',
    );
  }

  /// Pins/unpins [id] on the Home preview (max 3 pinned).
  LedgerState togglePin(String id) {
    final a = accountById(id);
    if (a == null) return this;
    if (a.pinned) {
      return copyWith(
        accounts: accounts
            .map((x) => x.id == id ? x.copyWith(pinned: false) : x)
            .toList(),
        toast: 'Unpinned from Home',
      );
    }
    if (accounts.where((x) => x.pinned).length >= 3) {
      return copyWith(toast: 'You can pin up to 3 accounts');
    }
    return copyWith(
      accounts: accounts
          .map((x) => x.id == id ? x.copyWith(pinned: true) : x)
          .toList(),
      toast: 'Pinned to Home',
    );
  }

  /// Deletes account [id] and its transactions, fixing draft/overlay references.
  LedgerState deleteAccount(String id) {
    if (accountById(id) == null) {
      return copyWith(acctSheetOpen: false, editingAccountId: '');
    }
    final remaining = accounts.where((a) => a.id != id).toList();
    var inc = incomeMonth, exp = expenseMonth;
    for (final t in transactions.where((t) => t.acctId == id)) {
      if (t.type == TxnType.income) {
        inc -= t.amount;
      } else if (t.type == TxnType.expense) {
        exp -= t.amount;
      }
    }
    final fallback = remaining.isNotEmpty ? remaining.first.id : '';
    return copyWith(
      accounts: remaining,
      transactions: transactions.where((t) => t.acctId != id).toList(),
      incomeMonth: inc,
      expenseMonth: exp,
      accountId: accountId == id ? fallback : accountId,
      toAccountId: toAccountId == id ? fallback : toAccountId,
      overlay: overlayAcct == id ? LedgerOverlay.none : overlay,
      overlayAcct: overlayAcct == id ? '' : overlayAcct,
      payCardId: payCardId == id ? '' : payCardId,
      acctSheetOpen: false,
      editingAccountId: '',
      toast: 'Account deleted',
    );
  }

  // ---- copyWith --------------------------------------------------------------

  LedgerState copyWith({
    AppTab? tab,
    bool? sheetOpen,
    LedgerOverlay? overlay,
    String? overlayAcct,
    bool? acctSheetOpen,
    String? payCardId,
    ActivePicker? picker,
    PickingSide? picking,
    TxnType? txnType,
    String? amount,
    String? payee,
    bool? invalid,
    String? accountId,
    String? toAccountId,
    String? categoryId,
    RepeatMode? repeat,
    int? installMonths,
    int? editingTxnId,
    DateTime? txnDate,
    String? editingAccountId,
    String? newName,
    String? newType,
    String? newCurrency,
    String? newBalance,
    bool? newInvalid,
    String? newLimit,
    String? newStatementDay,
    String? newDueDay,
    String? newStatementBalance,
    List<Account>? accounts,
    List<Txn>? transactions,
    List<Recurring>? recurring,
    double? incomeMonth,
    double? expenseMonth,
    String? search,
    String? toast,
  }) {
    return LedgerState(
      tab: tab ?? this.tab,
      sheetOpen: sheetOpen ?? this.sheetOpen,
      overlay: overlay ?? this.overlay,
      overlayAcct: overlayAcct ?? this.overlayAcct,
      acctSheetOpen: acctSheetOpen ?? this.acctSheetOpen,
      payCardId: payCardId ?? this.payCardId,
      picker: picker ?? this.picker,
      picking: picking ?? this.picking,
      txnType: txnType ?? this.txnType,
      amount: amount ?? this.amount,
      payee: payee ?? this.payee,
      invalid: invalid ?? this.invalid,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryId: categoryId ?? this.categoryId,
      repeat: repeat ?? this.repeat,
      installMonths: installMonths ?? this.installMonths,
      editingTxnId: editingTxnId ?? this.editingTxnId,
      txnDate: txnDate ?? this.txnDate,
      editingAccountId: editingAccountId ?? this.editingAccountId,
      newName: newName ?? this.newName,
      newType: newType ?? this.newType,
      newCurrency: newCurrency ?? this.newCurrency,
      newBalance: newBalance ?? this.newBalance,
      newInvalid: newInvalid ?? this.newInvalid,
      newLimit: newLimit ?? this.newLimit,
      newStatementDay: newStatementDay ?? this.newStatementDay,
      newDueDay: newDueDay ?? this.newDueDay,
      newStatementBalance: newStatementBalance ?? this.newStatementBalance,
      accounts: accounts ?? this.accounts,
      transactions: transactions ?? this.transactions,
      recurring: recurring ?? this.recurring,
      incomeMonth: incomeMonth ?? this.incomeMonth,
      expenseMonth: expenseMonth ?? this.expenseMonth,
      search: search ?? this.search,
      toast: toast ?? this.toast,
    );
  }
}
