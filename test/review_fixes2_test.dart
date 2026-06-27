import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/models/txn.dart';
import 'package:ledger/state/ledger_state.dart';

/// Second review-fix pass: statement rollback on edit/delete, FX-safe statement
/// payment, and weekly forecast occurrences. `citi` (seed) is a credit card,
/// balance −8420, statementBalance 6420, statementDay 5, dueDay 25.
void main() {
  final base = LedgerState.initial();

  LedgerState newCardInstallment() => base
      .copyWith(
        txnType: TxnType.expense,
        accountId: 'citi',
        categoryId: 'shopping',
        amount: '1200',
        installMonths: 6, // 200 / month
        repeat: RepeatMode.installment,
      )
      .save(close: true);

  group('statement charges roll back on edit / delete', () {
    test('Txn.statementBilled round-trips', () {
      final t = Txn(
        id: 1,
        type: TxnType.expense,
        amount: 10,
        payee: 'x',
        catId: 'c',
        acctId: 'citi',
        date: DateTime(2026, 6, 1),
        statementBilled: true,
      );
      expect(Txn.fromMap(t.toMap()).statementBilled, isTrue);
    });

    test('creating a card installment marks the row + bills the statement', () {
      final r = newCardInstallment();
      expect(r.transactions.first.statementBilled, isTrue);
      expect(r.accountById('citi')!.statementBalance, 6620); // 6420 + 200
    });

    test('deleting the installment charge reverses the statement', () {
      final created = newCardInstallment();
      final after = created.deleteTxn(created.transactions.first.id);
      expect(after.accountById('citi')!.statementBalance, 6420);
    });

    test('editing the amount re-bills the statement by the delta', () {
      final created = newCardInstallment();
      final edited = created
          .copyWith(
            editingTxnId: created.transactions.first.id,
            txnType: TxnType.expense,
            accountId: 'citi',
            categoryId: 'shopping',
            amount: '300',
          )
          .save(close: true);
      expect(after(edited), 6720); // 6420 reversed-200 +300
    });

    test('charging a card subscription then deleting it nets to zero', () {
      const sub = Recurring(
        id: 's',
        name: 'Netflix',
        amount: 78,
        freq: 'Monthly',
        next: 'x',
        catId: 'subs',
        kind: RecurringKind.sub,
        accountId: 'citi',
        nextDate: null,
      );
      final s = base.copyWith(recurring: [sub]);
      final charged = s.chargeToCard('s');
      expect(charged.accountById('citi')!.statementBalance, 6498); // 6420 + 78
      expect(charged.transactions.first.statementBilled, isTrue);
      final deleted = charged.deleteTxn(charged.transactions.first.id);
      expect(deleted.accountById('citi')!.statementBalance, 6420);
    });
  });

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
      nextDate: null,
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

double after(LedgerState s) => s.accountById('citi')!.statementBalance!;
