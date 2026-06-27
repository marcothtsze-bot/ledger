import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/txn.dart';
import 'package:ledger/state/ledger_state.dart';

/// The home/insights net-worth trend is reconstructed from real transactions —
/// no fabricated climb, and an honest null/empty when there's no history yet.
void main() {
  Account hk(String id, double bal) => Account(
    id: id,
    name: id,
    sub: '',
    letter: id[0],
    color: '#fff',
    bg: '#000',
    balance: bal,
    nature: AccountNature.asset,
  );

  Txn income(int id, double amt, DateTime date) => Txn(
    id: id,
    type: TxnType.income,
    amount: amt,
    payee: 'x',
    catId: 'salary',
    acctId: 'a',
    date: date,
  );

  group('netWorthAsOf', () {
    test('removes the effect of transactions dated after the day', () {
      final s = LedgerState.empty().copyWith(
        accounts: [hk('a', 1000)],
        transactions: [income(1, 300, DateTime(2026, 6, 20))],
      );
      expect(s.netWorth, 1000);
      expect(s.netWorthAsOf(DateTime(2026, 6, 19)), 700); // before the +300
      expect(s.netWorthAsOf(DateTime(2026, 6, 21)), 1000); // after it
    });
  });

  group('netWorthChangeSinceLastMonth', () {
    test('is null when there is no history before this month', () {
      final s = LedgerState.empty().copyWith(
        accounts: [hk('a', 1000)],
        transactions: [income(1, 100, DateTime(2026, 6, 5))],
      );
      expect(s.netWorthChangeSinceLastMonth(DateTime(2026, 6, 15)), isNull);
    });

    test('sums this-month movement once prior history exists', () {
      final s = LedgerState.empty().copyWith(
        accounts: [hk('a', 1000)],
        transactions: [
          income(1, 500, DateTime(2026, 5, 20)), // prior-month history
          income(2, 200, DateTime(2026, 6, 10)), // +200 this month
        ],
      );
      expect(s.netWorthChangeSinceLastMonth(DateTime(2026, 6, 15)), 200);
    });
  });

  group('netWorthTrend', () {
    test('is empty with fewer than two transactions', () {
      final s = LedgerState.empty().copyWith(
        accounts: [hk('a', 1000)],
        transactions: [income(1, 200, DateTime(2026, 6, 10))],
      );
      expect(s.netWorthTrend(), isEmpty);
    });

    test('has one point per recent txn and ends at current net worth', () {
      final s = LedgerState.empty().copyWith(
        accounts: [hk('a', 1000)],
        transactions: [
          income(1, 200, DateTime(2026, 6, 1)),
          income(2, 300, DateTime(2026, 6, 10)),
        ],
      );
      final t = s.netWorthTrend();
      expect(t.length, 2);
      expect(t.first, 700); // before the 2nd txn (+300): 1000 − 300
      expect(t.last, 1000); // ends at today's net worth
    });
  });
}
