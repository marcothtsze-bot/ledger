import 'dart:math';

import '../core/money.dart';
import '../core/statement.dart';
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
enum ActivePicker { none, account, category, repeat, date }

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
  final String catEditorId; // category editor: '' closed, 'new', or an id
  final String recurringEditorId; // recurring editor: '' closed, else an id
  final String payRecurringId; // pay/settle sheet: '' closed, else an id
  final bool backupOpen; // Backup & Restore sheet visibility
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
  final String newIcon; // chosen account icon ligature; '' = auto
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
  final List<Category> categories;
  final Map<String, double> budgets; // categoryId -> monthly limit
  final double incomeMonth;
  final double expenseMonth;

  // Transient
  final String search;
  final String filterAccountId; // '' = all accounts
  final String filterCategoryId; // '' = all categories
  final String filterType; // '' = all, else TxnType.name
  final bool filterOpen; // Activity filter panel visibility
  final String toast; // '' when nothing showing

  const LedgerState({
    required this.tab,
    required this.sheetOpen,
    required this.overlay,
    required this.overlayAcct,
    required this.acctSheetOpen,
    required this.payCardId,
    required this.catEditorId,
    required this.recurringEditorId,
    required this.payRecurringId,
    required this.backupOpen,
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
    required this.newIcon,
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
    required this.categories,
    required this.budgets,
    required this.incomeMonth,
    required this.expenseMonth,
    required this.search,
    required this.filterAccountId,
    required this.filterCategoryId,
    required this.filterType,
    required this.filterOpen,
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
    catEditorId: '',
    recurringEditorId: '',
    payRecurringId: '',
    backupOpen: false,
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
    newIcon: '',
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
    categories: kCategories,
    budgets: const {},
    incomeMonth: kSeedIncomeMonth,
    expenseMonth: kSeedExpenseMonth,
    search: '',
    filterAccountId: '',
    filterCategoryId: '',
    filterType: '',
    filterOpen: false,
    toast: '',
  );

  /// Rehydrates persisted data over the default draft/UI state.
  factory LedgerState.fromSnapshot(LedgerSnapshot s) {
    final cats = s.categories;
    // Keep the default draft category if it survived; otherwise fall back to the
    // first live category so a restored draft never points at a deleted id.
    const defaultCatId = 'dining';
    final draftCategoryId = cats.any((c) => c.id == defaultCatId)
        ? defaultCatId
        : (cats.isNotEmpty ? cats.first.id : defaultCatId);
    return LedgerState.initial().copyWith(
      accounts: s.accounts,
      transactions: s.transactions,
      recurring: s.recurring,
      categories: cats,
      budgets: s.budgets,
      categoryId: draftCategoryId,
      incomeMonth: s.incomeMonth,
      expenseMonth: s.expenseMonth,
    );
  }

  LedgerSnapshot toSnapshot() => LedgerSnapshot(
    accounts: accounts,
    transactions: transactions,
    recurring: recurring,
    categories: categories,
    budgets: budgets,
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
      categories.firstWhere((c) => c.id == id, orElse: () => _unknownCategory);

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

  bool get hasActiveFilters =>
      filterAccountId.isNotEmpty ||
      filterCategoryId.isNotEmpty ||
      filterType.isNotEmpty;

  /// Clears all Activity filters (leaves the search text alone).
  LedgerState clearFilters() => copyWith(
    filterAccountId: '',
    filterCategoryId: '',
    filterType: '',
  );

  /// Activity screen, filtered by [search] + the account/category/type filters,
  /// grouped by day (order preserved).
  List<ActivityGroup> get activityGroups {
    final q = search.trim().toLowerCase();
    final filtered = transactions.where((t) {
      if (filterAccountId.isNotEmpty &&
          t.acctId != filterAccountId &&
          t.toAcctId != filterAccountId) {
        return false;
      }
      if (filterCategoryId.isNotEmpty && t.catId != filterCategoryId) {
        return false;
      }
      if (filterType.isNotEmpty && t.type.name != filterType) return false;
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

  /// Sets the drafted transaction's date and closes the date picker.
  LedgerState pickDate(DateTime d) =>
      copyWith(txnDate: d, picker: ActivePicker.none);

  /// Commits the drafted transaction. Returns the state unchanged-but-`invalid`
  /// if the amount is not positive. [close] true = Save (close sheet, jump to
  /// Activity); false = "+ another" (keep sheet open, reset for rapid entry).
  LedgerState save({required bool close}) {
    final amt = parseAmount(amount);
    if (!(amt > 0)) return copyWith(invalid: true);
    if (editingTxnId != 0) return _editTxn(amt);

    // A scheduled future payment (weekly/monthly Repeat) is NOT posted now and
    // does NOT touch any balance — it only joins Upcoming, to be paid (account
    // chosen) when its due date arrives.
    if (repeat == RepeatMode.weekly || repeat == RepeatMode.monthly) {
      return _scheduleRecurring(amt, close: close);
    }

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
    if (repeat == RepeatMode.installment) {
      final cat = categoryById(categoryId);
      final nd = nextRecurringDate(txnDate, 'Monthly');
      newRecurring = [
        Recurring(
          id: 'u$txId',
          name: pay,
          amount: per,
          freq: 'Installment',
          next: '${monthAbbrev(nd.month)} ${nd.day}',
          catId: categoryId,
          kind: RecurringKind.installment,
          total: installMonths,
          paid: 1,
          icon: cat.icon,
          color: cat.color,
          accountId: accountId,
          nextDate: nd,
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

  /// Schedules a weekly/monthly Repeat as an Upcoming payment due on [txnDate],
  /// posting nothing and leaving every balance untouched until it is paid.
  LedgerState _scheduleRecurring(double amt, {required bool close}) {
    final freq = repeat == RepeatMode.monthly ? 'Monthly' : 'Weekly';
    final pay = payee.trim().isEmpty
        ? categoryById(categoryId).name
        : payee.trim();
    final cat = categoryById(categoryId);
    final due = DateTime(txnDate.year, txnDate.month, txnDate.day);
    final sched = Recurring(
      id: 'u$_nextTxnId',
      name: pay,
      amount: amt,
      freq: freq,
      next: '${monthAbbrev(due.month)} ${due.day}',
      catId: categoryId,
      kind: RecurringKind.sub,
      icon: cat.icon,
      color: cat.color,
      accountId: accountId,
      nextDate: due,
    );
    return copyWith(
      recurring: [sched, ...recurring],
      amount: '',
      payee: '',
      repeat: RepeatMode.off,
      invalid: false,
      sheetOpen: !close,
      tab: close ? AppTab.home : tab,
      toast: 'Payment scheduled',
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
      final newBal = existing.isLiability ? -balAbs : balAbs;
      final updated = existing.copyWith(
        name: name,
        icon: newIcon.isEmpty ? null : newIcon,
        balance: newBal,
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
      // Log a balance-adjustment record in Activity when the balance changed,
      // so the edit is traceable (the stored balance is authoritative; this
      // transaction is informational and doesn't re-apply to it).
      final delta = newBal - existing.balance;
      final txns = delta == 0
          ? transactions
          : [
              Txn(
                id: _nextTxnId,
                type: delta > 0 ? TxnType.income : TxnType.expense,
                amount: delta.abs(),
                payee: 'Balance adjustment',
                catId: categories.any((c) => c.id == 'payment')
                    ? 'payment'
                    : (categories.isNotEmpty ? categories.first.id : 'payment'),
                acctId: editingAccountId,
                date: DateTime.now(),
              ),
              ...transactions,
            ];
      return _closeAcctDraft().copyWith(
        accounts: next,
        transactions: txns,
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
      currency: newCurrency,
      balance: balance,
      nature: isLiab ? AccountNature.liability : AccountNature.asset,
      group: group,
      icon: newIcon.isEmpty ? null : newIcon,
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
    newIcon: '',
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

    // Resolve the payment category live — it can be edited/deleted now.
    final payCatId = categories.any((c) => c.id == 'payment')
        ? 'payment'
        : (categories.isNotEmpty ? categories.first.id : 'payment');
    final tx = Txn(
      id: _nextTxnId,
      type: TxnType.transfer,
      amount: amount,
      payee: '${card.name} payment',
      catId: payCatId,
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

  // ---- Category management ---------------------------------------------------

  /// Generates a stable, unique category id from [name] (slug, de-duplicated).
  String _uniqueCategoryId(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    // Cap pathological lengths so an id stays a reasonable key.
    final capped = slug.length > 24 ? slug.substring(0, 24) : slug;
    final base = capped.isEmpty ? 'cat' : capped;
    final taken = categories.map((c) => c.id).toSet();
    var id = base;
    var i = 2;
    while (taken.contains(id)) {
      id = '${base}_$i';
      i++;
    }
    return id;
  }

  /// Adds a new category to the end of the list.
  LedgerState addCategory({
    required String name,
    required String icon,
    required String color,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return this;
    final cat = Category(
      id: _uniqueCategoryId(trimmed),
      name: trimmed,
      color: color,
      icon: icon,
    );
    return copyWith(categories: [...categories, cat], toast: 'Category added');
  }

  /// Edits category [id] in place (name / icon / colour). A blank name is
  /// ignored so a category can't be saved nameless.
  LedgerState editCategory(
    String id, {
    String? name,
    String? icon,
    String? color,
  }) {
    if (!categories.any((c) => c.id == id)) return this;
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isEmpty) return this;
    return copyWith(
      categories: categories
          .map(
            (c) => c.id == id
                ? c.copyWith(name: trimmed, icon: icon, color: color)
                : c,
          )
          .toList(),
      toast: 'Category updated',
    );
  }

  /// Deletes category [id], reassigning any transactions, recurring rules and
  /// the draft selection that used it to the first remaining category so
  /// nothing is left orphaned. Refuses to delete the last remaining category
  /// (an empty list would silently re-seed from [kCategories] on next load).
  LedgerState deleteCategory(String id) {
    if (!categories.any((c) => c.id == id)) return this;
    final remaining = categories.where((c) => c.id != id).toList();
    if (remaining.isEmpty) {
      return copyWith(toast: 'Keep at least one category');
    }
    final fallback = remaining.first.id;
    return copyWith(
      categories: remaining,
      transactions: transactions
          .map((t) => t.catId == id ? t.copyWith(catId: fallback) : t)
          .toList(),
      recurring: recurring
          .map((r) => r.catId == id ? r.copyWith(catId: fallback) : r)
          .toList(),
      categoryId: categoryId == id ? fallback : categoryId,
      toast: 'Category deleted',
    );
  }

  // ---- Recurring management --------------------------------------------------

  /// Edits subscription/recurring [id] in place (name, amount, icon, colour,
  /// pay-from account, next-due date).
  LedgerState editRecurring(
    String id, {
    String? name,
    double? amount,
    String? icon,
    String? color,
    String? accountId,
    DateTime? nextDate,
    String? catId,
  }) {
    if (!recurring.any((r) => r.id == id)) return this;
    return copyWith(
      recurring: recurring
          .map(
            (r) => r.id == id
                ? r.copyWith(
                    name: name,
                    amount: amount,
                    icon: icon,
                    color: color,
                    accountId: accountId,
                    nextDate: nextDate,
                    catId: catId,
                  )
                : r,
          )
          .toList(),
      toast: 'Subscription updated',
    );
  }

  /// Cancels (deletes) recurring [id].
  LedgerState deleteRecurring(String id) {
    if (!recurring.any((r) => r.id == id)) return this;
    return copyWith(
      recurring: recurring.where((r) => r.id != id).toList(),
      toast: 'Subscription cancelled',
    );
  }

  /// Subscriptions/recurring whose next-due date is on or before [today].
  List<Recurring> dueRecurring(DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    return recurring
        .where((r) => r.nextDate != null && !r.nextDate!.isAfter(t))
        .toList();
  }

  /// Rolls a recurring item's schedule forward by its frequency (and bumps the
  /// paid count for installment plans).
  Recurring _advanceRecurring(Recurring r) {
    final from = r.nextDate ?? DateTime.now();
    final nd = nextRecurringDate(from, r.freq);
    return r.copyWith(
      nextDate: nd,
      next: '${monthAbbrev(nd.month)} ${nd.day}',
      paid: r.kind == RecurringKind.installment ? (r.paid ?? 0) + 1 : r.paid,
    );
  }

  /// Records paying recurring [id] from account [fromAccountId]: posts an
  /// expense, debits the account, and advances the schedule.
  LedgerState payRecurring(String id, String fromAccountId) {
    if (!recurring.any((r) => r.id == id)) return this;
    final r = recurring.firstWhere((x) => x.id == id);
    if (accountById(fromAccountId) == null) return this;

    final catId = categories.any((c) => c.id == r.catId)
        ? r.catId
        : (categories.isNotEmpty ? categories.first.id : r.catId);
    final tx = Txn(
      id: _nextTxnId,
      type: TxnType.expense,
      amount: r.amount,
      payee: r.name,
      catId: catId,
      acctId: fromAccountId,
      date: DateTime.now(),
    );
    final newAccounts = accounts
        .map(
          (a) =>
              a.id == fromAccountId ? a.copyWith(balance: a.balance - r.amount) : a,
        )
        .toList();
    return copyWith(
      transactions: [tx, ...transactions],
      accounts: newAccounts,
      expenseMonth: expenseMonth + r.amount,
      recurring: recurring
          .map((x) => x.id == id ? _advanceRecurring(x) : x)
          .toList(),
      toast: 'Paid ${r.name}',
    );
  }

  /// Marks recurring [id] as settled (handled elsewhere): advances the schedule
  /// without recording a transaction or touching any balance.
  LedgerState settleRecurring(String id) {
    if (!recurring.any((r) => r.id == id)) return this;
    return copyWith(
      recurring: recurring
          .map((x) => x.id == id ? _advanceRecurring(x) : x)
          .toList(),
      toast: 'Marked settled',
    );
  }

  // ---- Budgets ---------------------------------------------------------------

  /// This month's expense total per category (id -> amount) for [now], used to
  /// track spending against each category's budget.
  Map<String, double> categorySpendThisMonth(DateTime now) {
    final out = <String, double>{};
    for (final t in transactions) {
      if (t.type != TxnType.expense) continue;
      if (t.date.year != now.year || t.date.month != now.month) continue;
      out[t.catId] = (out[t.catId] ?? 0) + t.amount;
    }
    return out;
  }

  /// Sets, or clears when [amount] <= 0, the monthly budget for [categoryId].
  LedgerState setCategoryBudget(String categoryId, double amount) {
    final next = Map<String, double>.from(budgets);
    if (amount > 0) {
      next[categoryId] = amount;
    } else {
      next.remove(categoryId);
    }
    return copyWith(budgets: next);
  }

  // ---- copyWith --------------------------------------------------------------

  LedgerState copyWith({
    AppTab? tab,
    bool? sheetOpen,
    LedgerOverlay? overlay,
    String? overlayAcct,
    bool? acctSheetOpen,
    String? payCardId,
    String? catEditorId,
    String? recurringEditorId,
    String? payRecurringId,
    bool? backupOpen,
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
    String? newIcon,
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
    List<Category>? categories,
    Map<String, double>? budgets,
    double? incomeMonth,
    double? expenseMonth,
    String? search,
    String? filterAccountId,
    String? filterCategoryId,
    String? filterType,
    bool? filterOpen,
    String? toast,
  }) {
    return LedgerState(
      tab: tab ?? this.tab,
      sheetOpen: sheetOpen ?? this.sheetOpen,
      overlay: overlay ?? this.overlay,
      overlayAcct: overlayAcct ?? this.overlayAcct,
      acctSheetOpen: acctSheetOpen ?? this.acctSheetOpen,
      payCardId: payCardId ?? this.payCardId,
      catEditorId: catEditorId ?? this.catEditorId,
      recurringEditorId: recurringEditorId ?? this.recurringEditorId,
      payRecurringId: payRecurringId ?? this.payRecurringId,
      backupOpen: backupOpen ?? this.backupOpen,
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
      newIcon: newIcon ?? this.newIcon,
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
      categories: categories ?? this.categories,
      budgets: budgets ?? this.budgets,
      incomeMonth: incomeMonth ?? this.incomeMonth,
      expenseMonth: expenseMonth ?? this.expenseMonth,
      search: search ?? this.search,
      filterAccountId: filterAccountId ?? this.filterAccountId,
      filterCategoryId: filterCategoryId ?? this.filterCategoryId,
      filterType: filterType ?? this.filterType,
      filterOpen: filterOpen ?? this.filterOpen,
      toast: toast ?? this.toast,
    );
  }
}
