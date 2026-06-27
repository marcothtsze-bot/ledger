import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

/// FX-safe statement payment and weekly forecast occurrences. `citi` (seed) is
/// a credit card, balance −8420, statementBalance 6420, statementDay 5, dueDay 25.
void main() {
  final base = LedgerState.initial();

  group('paying a statement is FX-safe', () {
    test('a US\$ card statement paid from HK\$ debits the HK\$ equivalent', () {
      final s = base.copyWith(
        accounts: base.accounts
            .map(
              (a) => a.id == 'citi'
                  ? a.copyWith(
                      currency: 'USD',
                      fxRate: 7.8,
                      statementBalance: 100,
                    )
                  : a,
            )
            .toList(),
        payCardId: 'citi',
      );
      final hsbc0 = s.accountById('hsbc')!.balance;
      final r = s.payStatement('hsbc');

      // 100 USD statement = 780 HKD off the paying account.
      expect(r.accountById('hsbc')!.balance, closeTo(hsbc0 - 780, 1e-6));
      expect(r.accountById('citi')!.statementBalance, 0);
      expect(r.transactions.first.toAcctId, 'citi');
      expect(r.netWorth, closeTo(s.netWorth, 1e-6)); // payment is net-zero
    });
  });

  group('forecast counts weekly occurrences before the close', () {
    final now = DateTime(2026, 6, 20); // citi statementDay 5 → close Jul 5
    const weekly = Recurring(
      id: 'w',
      name: 'Weekly',
      amount: 10,
      freq: 'Weekly',
      next: 'x',
      catId: 'subs',
      kind: RecurringKind.sub,
      accountId: 'citi',
    );

    test('weekly recurs Jun 22 + Jun 29 (Jul 6 is past close) = 2 charges', () {
      final w = weekly.copyWith(nextDate: DateTime(2026, 6, 22));
      final s = base.copyWith(recurring: [w]);
      expect(s.chargesBeforeNextClose(w, 'citi', now), 2);
      expect(s.committedToNextStatement('citi', now), 20); // 10 × 2
    });

    test('a monthly item charges at most once per statement', () {
      final m = weekly.copyWith(freq: 'Monthly', nextDate: DateTime(2026, 6, 25));
      final s = base.copyWith(recurring: [m]);
      expect(s.chargesBeforeNextClose(m, 'citi', now), 1);
    });
  });
}
