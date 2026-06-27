import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/txn.dart';
import 'package:ledger/state/ledger_state.dart';

/// The Insights cash-flow and spending cards read real, currency-converted
/// data from these pure derivations.
void main() {
  Account hk(String id) => Account(
    id: id,
    name: id,
    sub: '',
    letter: id[0],
    color: '#fff',
    bg: '#000',
    balance: 0,
    nature: AccountNature.asset,
  );

  Account jpy(String id) => Account(
    id: id,
    name: id,
    sub: '',
    letter: id[0],
    color: '#fff',
    bg: '#000',
    currency: 'JPY',
    fxRate: 0.05,
    balance: 0,
    nature: AccountNature.asset,
  );

  Txn tx(
    int id,
    TxnType type,
    double amt,
    String acctId,
    String catId,
    DateTime date,
  ) => Txn(
    id: id,
    type: type,
    amount: amt,
    payee: 'x',
    catId: catId,
    acctId: acctId,
    date: date,
  );

  group('monthlyFlow', () {
    test('buckets income/expense per month, oldest → newest, in HKD', () {
      final s = LedgerState.empty().copyWith(
        accounts: [hk('a'), jpy('jp')],
        transactions: [
          tx(1, TxnType.income, 1000, 'a', 'salary', DateTime(2026, 6, 5)),
          tx(2, TxnType.expense, 200, 'a', 'dining', DateTime(2026, 6, 6)),
          tx(3, TxnType.expense, 1000, 'jp', 'dining', DateTime(2026, 5, 10)),
          tx(4, TxnType.income, 500, 'a', 'salary', DateTime(2026, 4, 1)),
          tx(5, TxnType.transfer, 999, 'a', 'payment', DateTime(2026, 6, 2)),
        ],
      );
      final flows = s.monthlyFlow(DateTime(2026, 6, 15), 3); // Apr, May, Jun

      expect(flows.length, 3);
      expect(flows.first.month.month, 4, reason: 'oldest first');
      expect(flows.last.month.month, 6, reason: 'newest last');
      expect(flows[0].income, 500); // Apr
      expect(flows[1].expense, closeTo(50, 1e-6)); // May ¥1000 @0.05
      expect(flows[2].income, 1000); // Jun (transfer ignored)
      expect(flows[2].expense, 200);
      expect(flows[2].net, 800);
    });

    test('a month with no activity reads as zero', () {
      final s = LedgerState.empty().copyWith(accounts: [hk('a')]);
      final flows = s.monthlyFlow(DateTime(2026, 6, 15), 2);
      expect(flows.length, 2);
      expect(flows.every((f) => f.income == 0 && f.expense == 0), isTrue);
    });
  });

  group('categorySpendInRange', () {
    test('sums expenses by category in range, converting currency', () {
      final s = LedgerState.empty().copyWith(
        accounts: [hk('a'), jpy('jp')],
        transactions: [
          tx(1, TxnType.expense, 300, 'a', 'dining', DateTime(2026, 6, 5)),
          tx(2, TxnType.expense, 100, 'a', 'dining', DateTime(2026, 6, 20)),
          tx(3, TxnType.expense, 2000, 'jp', 'shopping', DateTime(2026, 6, 10)),
          tx(4, TxnType.expense, 999, 'a', 'dining', DateTime(2026, 3, 1)),
          tx(5, TxnType.income, 5000, 'a', 'salary', DateTime(2026, 6, 1)),
        ],
      );
      final spend = s.categorySpendInRange(
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 30),
      );
      expect(spend['dining'], 400); // 300 + 100, March one excluded
      expect(spend['shopping'], closeTo(100, 1e-6)); // ¥2000 @0.05
      expect(spend.containsKey('salary'), isFalse); // income excluded
    });
  });
}
