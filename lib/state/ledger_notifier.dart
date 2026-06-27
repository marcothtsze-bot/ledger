import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/fx.dart';
import '../data/backup.dart';
import '../data/ledger_repository.dart';
import '../models/enums.dart';
import '../models/txn.dart';
import 'ledger_state.dart';

const _toastDuration = Duration(milliseconds: 1900);

/// Provides the concrete repository. Overridden in `main()` with the on-device
/// SQLite implementation; tests override it with an in-memory fake.
final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  throw UnimplementedError('Override ledgerRepositoryProvider before use');
});

/// The single source of truth for the running app.
final ledgerProvider = NotifierProvider<LedgerNotifier, LedgerState>(
  LedgerNotifier.new,
);

/// Thin Riverpod wrapper around [LedgerState]. All real logic lives on the
/// immutable state; this class only wires actions to `state = ...` and handles
/// the two side effects: persistence and the auto-dismissing toast timer.
class LedgerNotifier extends Notifier<LedgerState> {
  Timer? _toastTimer;

  @override
  LedgerState build() {
    ref.onDispose(() => _toastTimer?.cancel());
    _hydrate();
    return LedgerState.empty();
  }

  LedgerRepository get _repo => ref.read(ledgerRepositoryProvider);

  Future<void> _hydrate() async {
    final snap = await _repo.load();
    if (snap == null) {
      // First run: persist the empty starting state so the app opens blank and
      // the user builds their own data from scratch.
      await _repo.persist(state.toSnapshot());
    } else {
      state = LedgerState.fromSnapshot(snap);
    }
  }

  void _persist() => unawaited(_repo.persist(state.toSnapshot()));

  void _startToastTimer() {
    _toastTimer?.cancel();
    _toastTimer = Timer(
      _toastDuration,
      () => state = state.copyWith(toast: ''),
    );
  }

  // ---- Navigation / chrome ----
  void goTab(AppTab t) =>
      state = state.copyWith(tab: t, overlay: LedgerOverlay.none);
  void openSheet() => state = state.copyWith(
    sheetOpen: true,
    editingTxnId: 0,
    txnDate: DateTime.now(),
    recurEnd: null,
    note: '',
    categoryTouched: false,
    picker: ActivePicker.none,
  );
  void closeSheet() => state = state.copyWith(
    sheetOpen: false,
    editingTxnId: 0,
    amount: '',
    payee: '',
    note: '',
    categoryTouched: false,
    repeat: RepeatMode.off,
    recurEnd: null,
    invalid: false,
    picker: ActivePicker.none,
  );

  /// Opens the sheet pre-filled to edit an existing transaction.
  void openEditTxn(int id) {
    Txn? t;
    for (final x in state.transactions) {
      if (x.id == id) {
        t = x;
        break;
      }
    }
    if (t == null) return;
    state = state.copyWith(
      sheetOpen: true,
      editingTxnId: id,
      txnDate: t.date,
      txnType: t.type,
      amount: _amountString(t.amount),
      payee: t.payee,
      note: t.note ?? '',
      categoryTouched: true, // editing: keep the txn's category, no auto-fill
      categoryId: t.catId,
      accountId: t.acctId,
      toAccountId: t.toAcctId ?? state.toAccountId,
      repeat: RepeatMode.off,
      invalid: false,
      picker: ActivePicker.none,
    );
  }

  void deleteTxn(int id) {
    final next = state.deleteTxn(id);
    state = next;
    if (next.toast.isNotEmpty) {
      _persist();
      _startToastTimer();
    }
  }

  static String _amountString(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Formats an FX rate for the editable field, trimming a redundant `.0`.
  static String _rateString(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  void openRecurring() =>
      state = state.copyWith(overlay: LedgerOverlay.recurring);
  void openAccount(String id) =>
      state = state.copyWith(overlay: LedgerOverlay.account, overlayAcct: id);
  void closeOverlay() =>
      state = state.copyWith(overlay: LedgerOverlay.none, overlayAcct: '');
  void openAcctSheet() => state = state.copyWith(
    acctSheetOpen: true,
    editingAccountId: '',
    newName: '',
    newIcon: '',
    newType: 'Debit',
    newCurrency: 'HKD',
    newFxRate: '',
    newBalance: '',
    newInvalid: false,
    newLimit: '',
    newStatementDay: '',
    newDueDay: '',
    newStatementBalance: '',
  );

  /// Opens the sheet pre-filled to edit an existing account.
  void openEditAccount(String id) {
    final a = state.accountById(id);
    if (a == null) return;
    String num0(double? v) => v == null ? '' : v.abs().toStringAsFixed(0);
    state = state.copyWith(
      acctSheetOpen: true,
      editingAccountId: id,
      newName: a.name,
      newIcon: a.icon ?? '',
      newType: a.isLiability ? 'Credit' : 'Debit',
      newCurrency: a.currency,
      newFxRate: a.currency.toUpperCase() == kBaseCurrency
          ? ''
          : _rateString(a.fxRate ?? defaultRateToHkd(a.currency)),
      newBalance: a.balance == 0 ? '' : num0(a.balance),
      newInvalid: false,
      newLimit: num0(a.creditLimit),
      newStatementDay: a.statementDay?.toString() ?? '',
      newDueDay: a.dueDay?.toString() ?? '',
      newStatementBalance: num0(a.statementBalance),
    );
  }

  void closeAcctSheet() => state = state.copyWith(
    acctSheetOpen: false,
    editingAccountId: '',
    newName: '',
    newIcon: '',
    newFxRate: '',
    newBalance: '',
    newInvalid: false,
    newLimit: '',
    newStatementDay: '',
    newDueDay: '',
    newStatementBalance: '',
  );

  void openPayStatement(String cardId) =>
      state = state.copyWith(payCardId: cardId);
  void closePayStatement() => state = state.copyWith(payCardId: '');
  void payStatement(String fromId) {
    final next = state.payStatement(fromId);
    state = next;
    if (next.toast.isNotEmpty) {
      _persist();
      _startToastTimer();
    }
  }

  void togglePin(String id) {
    final before = state.accounts;
    state = state.togglePin(id);
    if (!identical(state.accounts, before)) _persist();
    if (state.toast.isNotEmpty) _startToastTimer();
  }

  void deleteAccount(String id) {
    state = state.deleteAccount(id);
    _persist();
    if (state.toast.isNotEmpty) _startToastTimer();
  }

  // ---- Add Transaction draft ----
  void setTxnType(TxnType t) => state = state.copyWith(txnType: t);
  void press(String key) => state = state.pressKey(key);

  /// Sets the payee and, when adding a new transaction and the user hasn't
  /// already picked a category, auto-fills the category from that payee's
  /// history (a known payee preselects its usual category).
  void setPayee(String v) {
    var next = state.copyWith(payee: v);
    if (next.editingTxnId == 0 && !next.categoryTouched) {
      final cat = next.suggestCategoryForPayee(v);
      if (cat != null) next = next.copyWith(categoryId: cat);
    }
    state = next;
  }

  void setNote(String v) => state = state.copyWith(note: v);

  // Activity month navigation.
  void prevMonth() => state = state.copyWith(
    filterMonth: DateTime(state.filterMonth.year, state.filterMonth.month - 1),
  );
  void nextMonth() => state = state.copyWith(
    filterMonth: DateTime(state.filterMonth.year, state.filterMonth.month + 1),
  );
  void incMonths() => state = state.copyWith(
    installMonths: state.installMonths < 36 ? state.installMonths + 1 : 36,
  );
  void decMonths() => state = state.copyWith(
    installMonths: state.installMonths > 2 ? state.installMonths - 1 : 2,
  );

  // ---- Pickers ----
  void openAccountPicker() => state = state.copyWith(
    picker: ActivePicker.account,
    picking: PickingSide.from,
  );
  void openToPicker() => state = state.copyWith(
    picker: ActivePicker.account,
    picking: PickingSide.to,
  );
  void openCategoryPicker() =>
      state = state.copyWith(picker: ActivePicker.category);
  void openRepeatPicker() =>
      state = state.copyWith(picker: ActivePicker.repeat);
  void openDatePicker() => state = state.copyWith(picker: ActivePicker.date);
  void openRecurEndPicker() =>
      state = state.copyWith(picker: ActivePicker.recurEnd);

  /// Sets the drafted monthly-repeat end date (null = ongoing) and closes the
  /// picker.
  void setRecurEnd(DateTime? d) =>
      state = state.copyWith(recurEnd: d, picker: ActivePicker.none);
  void closePicker() => state = state.copyWith(picker: ActivePicker.none);
  void pickAccount(String id) => state = state.picking == PickingSide.to
      ? state.copyWith(toAccountId: id, picker: ActivePicker.none)
      : state.copyWith(accountId: id, picker: ActivePicker.none);
  void pickCategory(String id) => state = state.copyWith(
    categoryId: id,
    categoryTouched: true, // manual pick → don't let payee auto-fill override it
    picker: ActivePicker.none,
  );
  void pickDate(DateTime d) => state = state.pickDate(d);
  void setRepeat(RepeatMode r) => state = state.copyWith(repeat: r);

  // ---- Category management ----
  void openNewCategory() => state = state.copyWith(catEditorId: 'new');
  void openEditCategory(String id) => state = state.copyWith(catEditorId: id);
  void closeCategoryEditor() => state = state.copyWith(catEditorId: '');

  void saveCategory({
    required String name,
    required String icon,
    required String color,
    double budget = 0,
  }) {
    final id = state.catEditorId;
    var next = id == 'new'
        ? state.addCategory(name: name, icon: icon, color: color)
        : state.editCategory(id, name: name, icon: icon, color: color);
    // For a new category the id is generated inside addCategory, so resolve it
    // from the freshly-appended entry; set (or clear) its monthly budget.
    final catId = id == 'new' ? next.categories.last.id : id;
    next = next.setCategoryBudget(catId, budget);
    state = next.copyWith(catEditorId: '');
    if (next.toast.isNotEmpty) {
      _persist();
      _startToastTimer();
    }
  }

  void deleteCategoryById(String id) {
    state = state.deleteCategory(id).copyWith(catEditorId: '');
    _persist();
    if (state.toast.isNotEmpty) _startToastTimer();
  }

  // ---- Add Account draft ----
  void setNewName(String v) =>
      state = state.copyWith(newName: v, newInvalid: false);
  void setNewIcon(String v) => state = state.copyWith(newIcon: v);
  void setNewType(String v) => state = state.copyWith(newType: v);

  /// Picks the account currency and, for a non-base currency, pre-fills the
  /// rate field with the built-in default so the user sees a sensible number to
  /// keep or correct (cleared back to blank for the base currency).
  void setNewCurrency(String v) => state = state.copyWith(
    newCurrency: v,
    newFxRate: v.toUpperCase() == kBaseCurrency
        ? ''
        : _rateString(defaultRateToHkd(v)),
  );
  void setNewFxRate(String v) => state = state.copyWith(newFxRate: v);
  void setNewBalance(String v) => state = state.copyWith(newBalance: v);
  void setNewLimit(String v) => state = state.copyWith(newLimit: v);
  void setNewStatementDay(String v) =>
      state = state.copyWith(newStatementDay: v);
  void setNewDueDay(String v) => state = state.copyWith(newDueDay: v);
  void setNewStatementBalance(String v) =>
      state = state.copyWith(newStatementBalance: v);

  // ---- Activity ----
  void setSearch(String v) => state = state.copyWith(search: v);
  void toggleFilter() => state = state.copyWith(filterOpen: !state.filterOpen);
  void setFilterAccount(String id) =>
      state = state.copyWith(filterAccountId: id);
  void setFilterCategory(String id) =>
      state = state.copyWith(filterCategoryId: id);
  void setFilterType(String t) => state = state.copyWith(filterType: t);
  void clearFilters() => state = state.clearFilters();

  // ---- Commits (with side effects) ----
  void save({required bool close}) {
    final next = state.save(close: close);
    state = next;
    if (next.toast.isNotEmpty) {
      _persist();
      _startToastTimer();
    }
  }

  void saveAccount() {
    final next = state.saveAccount();
    state = next;
    if (next.toast.isNotEmpty) {
      _persist();
      _startToastTimer();
    }
  }

  // ---- Recurring management ----
  void openEditRecurring(String id) =>
      state = state.copyWith(recurringEditorId: id);
  void closeRecurringEditor() => state = state.copyWith(recurringEditorId: '');

  void saveRecurring(
    String id, {
    required String name,
    required double amount,
    required String icon,
    required String color,
    required String accountId,
    required DateTime nextDate,
    DateTime? endDate,
  }) {
    state = state
        .editRecurring(
          id,
          name: name,
          amount: amount,
          icon: icon,
          color: color,
          accountId: accountId,
          nextDate: nextDate,
          endDate: endDate,
        )
        .copyWith(recurringEditorId: '');
    if (state.toast.isNotEmpty) {
      _persist();
      _startToastTimer();
    }
  }

  void deleteRecurringById(String id) {
    state = state.deleteRecurring(id).copyWith(recurringEditorId: '');
    _persist();
    if (state.toast.isNotEmpty) _startToastTimer();
  }

  void mergeDuplicateRecurring() {
    state = state.mergeDuplicateRecurring();
    _persist();
    if (state.toast.isNotEmpty) _startToastTimer();
  }

  // ---- Pay / settle an upcoming payment ----
  void openSettleRecurring(String id) =>
      state = state.copyWith(payRecurringId: id);
  void closeSettleRecurring() => state = state.copyWith(payRecurringId: '');

  void payRecurring(String id, String fromAccountId) {
    state = state.payRecurring(id, fromAccountId).copyWith(payRecurringId: '');
    if (state.toast.isNotEmpty) {
      _persist();
      _startToastTimer();
    }
  }

  void settleRecurring(String id) {
    state = state.settleRecurring(id).copyWith(payRecurringId: '');
    if (state.toast.isNotEmpty) {
      _persist();
      _startToastTimer();
    }
  }

  void chargeToCard(String id) {
    state = state.chargeToCard(id).copyWith(payRecurringId: '');
    if (state.toast.isNotEmpty) {
      _persist();
      _startToastTimer();
    }
  }

  /// Shows a short auto-dismissing toast with [message].
  void flashToast(String message) {
    state = state.copyWith(toast: message);
    _startToastTimer();
  }

  // ---- Backup & restore ----
  void openBackup() => state = state.copyWith(backupOpen: true);
  void closeBackup() => state = state.copyWith(backupOpen: false);

  /// The full data as a portable JSON backup string.
  String exportBackup() => exportBackupJson(state.toSnapshot());

  /// Replaces all data from a backup JSON string. Returns `null` on success,
  /// or a user-facing error message.
  String? restoreBackup(String raw) {
    final LedgerSnapshot snap;
    try {
      snap = importBackupJson(raw);
    } on FormatException catch (e) {
      return e.message;
    } on Object {
      return "Couldn't read that backup.";
    }
    state = LedgerState.fromSnapshot(snap).copyWith(toast: 'Backup restored');
    _persist();
    _startToastTimer();
    return null;
  }
}
