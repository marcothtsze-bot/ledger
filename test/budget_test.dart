import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/txn.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  group('budgets', () {
    Txn exp(int id, String cat, double amt, DateTime d) => Txn(
      id: id,
      type: TxnType.expense,
      amount: amt,
      payee: 'p$id',
      catId: cat,
      acctId: 'hsbc',
      date: d,
    );

    test('categorySpendThisMonth sums current-month expenses by category', () {
      final now = DateTime(2026, 6, 15);
      final s = LedgerState.initial().copyWith(
        transactions: [
          exp(1, 'dining', 100, DateTime(2026, 6, 3)),
          exp(2, 'dining', 50, DateTime(2026, 6, 10)),
          exp(3, 'transport', 30, DateTime(2026, 6, 12)),
          exp(4, 'dining', 999, DateTime(2026, 5, 20)), // last month
          Txn(
            id: 5,
            type: TxnType.income,
            amount: 9999,
            payee: 'salary',
            catId: 'salary',
            acctId: 'hsbc',
            date: DateTime(2026, 6, 1),
          ),
        ],
      );
      final spend = s.categorySpendThisMonth(now);
      expect(spend['dining'], 150);
      expect(spend['transport'], 30);
      expect(spend.containsKey('salary'), isFalse); // income excluded
    });

    test('setCategoryBudget sets and clears a category budget', () {
      final s = LedgerState.initial().setCategoryBudget('dining', 2000);
      expect(s.budgets['dining'], 2000);
      final cleared = s.setCategoryBudget('dining', 0);
      expect(cleared.budgets.containsKey('dining'), isFalse);
    });

    test('budgets survive a snapshot round-trip', () {
      final s = LedgerState.initial().setCategoryBudget('dining', 1500);
      final restored = LedgerState.fromSnapshot(s.toSnapshot());
      expect(restored.budgets['dining'], 1500);
    });
  });
}
