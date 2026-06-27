import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

/// Committed-but-unbilled installment months are held against a credit card's
/// available credit (like a real merchant installment plan), not just the
/// already-charged balance.
void main() {
  test('committed installments reserve against available credit', () {
    const card = Account(
      id: 'rc',
      name: 'RedCard',
      sub: '',
      letter: 'R',
      color: '#fff',
      bg: '#000',
      balance: -210, // first installment already charged
      nature: AccountNature.liability,
      group: 'credit',
      creditLimit: 5000,
    );
    const inst = Recurring(
      id: 'i',
      name: 'Smartone',
      amount: 210,
      freq: 'Installment',
      next: 'x',
      catId: 'phone',
      kind: RecurringKind.installment,
      total: 3,
      paid: 1,
      accountId: 'rc',
    );
    final s = LedgerState.empty().copyWith(accounts: [card], recurring: [inst]);

    expect(s.installmentCommitmentRemaining('rc'), 420); // (3 − 1) × 210
    expect(s.cardReserved('rc'), 630); // 210 owed + 420 committed
    // → available = 5000 − 630 = 4370 (vs 4790 on the balance alone)
  });

  test('a card with no installments reserves only its balance', () {
    const card = Account(
      id: 'c',
      name: 'C',
      sub: '',
      letter: 'C',
      color: '#fff',
      bg: '#000',
      balance: -1000,
      nature: AccountNature.liability,
      group: 'credit',
      creditLimit: 5000,
    );
    final s = LedgerState.empty().copyWith(accounts: [card]);
    expect(s.installmentCommitmentRemaining('c'), 0);
    expect(s.cardReserved('c'), 1000);
  });
}
