import '../models/account.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../models/txn.dart';

/// An immutable snapshot of everything the app persists, including the
/// (now user-editable) category list.
class LedgerSnapshot {
  final List<Account> accounts;
  final List<Txn> transactions;
  final List<Recurring> recurring;
  final List<Category> categories;
  final Map<String, double> budgets;
  final double incomeMonth;
  final double expenseMonth;

  const LedgerSnapshot({
    required this.accounts,
    required this.transactions,
    required this.recurring,
    required this.categories,
    required this.budgets,
    required this.incomeMonth,
    required this.expenseMonth,
  });
}

/// Storage boundary for the ledger (Repository pattern). Business logic depends
/// on this interface, never on a concrete database — so persistence can be
/// swapped (SQLite, in-memory for tests, a future sync backend) freely.
abstract class LedgerRepository {
  /// Returns the persisted snapshot, or `null` if nothing has been stored yet
  /// (first run) so the caller can seed.
  Future<LedgerSnapshot?> load();

  /// Replaces the persisted state with [snapshot].
  Future<void> persist(LedgerSnapshot snapshot);

  /// Clears all persisted data (used by "reset" / tests).
  Future<void> reset();
}
