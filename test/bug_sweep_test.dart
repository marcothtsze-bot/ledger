import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/core/fx.dart';
import 'package:ledger/core/statement.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

/// Regression tests for the 8 bugs found in the Codex × Claude full-app sweep.
void main() {
  Account acct(
    String id, {
    String currency = 'HKD',
    double? fxRate,
    double balance = 0,
    AccountNature nature = AccountNature.asset,
    String group = 'cashbank',
    double? creditLimit,
    int? statementDay,
    int? dueDay,
    double? statementBalance,
  }) => Account(
    id: id,
    name: id,
    sub: '',
    letter: id.substring(0, 1).toUpperCase(),
    color: '#fff',
    bg: '#000',
    currency: currency,
    fxRate: fxRate,
    balance: balance,
    nature: nature,
    group: group,
    creditLimit: creditLimit,
    statementDay: statementDay,
    dueDay: dueDay,
    statementBalance: statementBalance,
  );

  group('Bug 1 — cross-currency statement payment', () {
    test('paying a HKD card from a JPY account reverses cleanly on delete', () {
      final jpy = acct('jpy', currency: 'JPY', fxRate: 0.05, balance: 10000);
      final card = acct(
        'card',
        balance: -100,
        nature: AccountNature.liability,
        group: 'credit',
        creditLimit: 5000,
        statementDay: 10,
        dueDay: 1,
        statementBalance: 100, // HKD owed
      );
      var s = LedgerState.empty().copyWith(
        accounts: [jpy, card],
        payCardId: 'card',
      );
      final nwBefore = s.netWorth;

      s = s.payStatement('jpy');
      // 100 HKD owed → 2000 JPY debited; card cleared.
      expect(s.accountById('jpy')!.balance, closeTo(8000, 0.001));
      expect(s.accountById('card')!.balance, closeTo(0, 0.001));
      expect(s.netWorth, closeTo(nwBefore, 0.5)); // payment moves no net worth

      // Deleting the payment must restore −100 on the card, NOT −2100.
      final txId = s.transactions.first.id;
      s = s.deleteTxn(txId);
      expect(s.accountById('card')!.balance, closeTo(-100, 0.001));
      expect(s.accountById('jpy')!.balance, closeTo(10000, 0.001));
      expect(s.netWorth, closeTo(nwBefore, 0.5));
    });
  });

  group('Bug 2 — installment seed ↔ plan link', () {
    LedgerState makePlan() => LedgerState.empty()
        .copyWith(
          accounts: [acct('cash', balance: 5000)],
          repeat: RepeatMode.installment,
          installMonths: 6,
          amount: '600',
          accountId: 'cash',
          categoryId: 'dining',
          payee: 'Phone',
        )
        .save(close: true);

    test('the seed transaction is linked to its plan', () {
      final s = makePlan();
      expect(s.recurring.length, 1);
      final seed = s.transactions.firstWhere((t) => t.recurringId != null);
      expect(seed.recurringId, s.recurring.first.id);
    });

    test('deleting the seed cancels the plan (no orphan paid=1)', () {
      var s = makePlan();
      final seed = s.transactions.firstWhere((t) => t.recurringId != null);
      s = s.deleteTxn(seed.id);
      expect(s.recurring, isEmpty);
    });

    test('editing the seed amount updates the linked plan amount', () {
      var s = makePlan();
      final seed = s.transactions.firstWhere((t) => t.recurringId != null);
      expect(s.recurring.first.amount, 100); // 600 / 6
      s = s
          .copyWith(
            editingTxnId: seed.id,
            txnType: TxnType.expense,
            accountId: 'cash',
            categoryId: 'dining',
            payee: 'Phone',
            amount: '150',
          )
          .save(close: true);
      expect(s.recurring.first.amount, 150);
    });
  });

  group('Bug 4 — merge safety', () {
    test('distinct-frequency subscriptions are NOT treated as duplicates', () {
      final weekly = Recurring(
        id: 'w',
        name: 'Loan',
        amount: 500,
        freq: 'Weekly',
        next: 'x',
        catId: 'loan',
        kind: RecurringKind.sub,
        accountId: 'a',
      );
      final monthly = weekly.copyWith(id: 'm', freq: 'Monthly');
      final s = LedgerState.empty().copyWith(recurring: [weekly, monthly]);
      expect(s.duplicateRecurringCount, 0);
      expect(s.mergeDuplicateRecurring().recurring.length, 2);
    });
  });

  group('Bug 5 — month-end date anchor', () {
    test('a Jan-31 monthly bill stays on the 31st, not drifting to 28', () {
      final feb = nextRecurringDate(DateTime(2026, 1, 31), 'Monthly', anchorDay: 31);
      expect(feb, DateTime(2026, 2, 28));
      final mar = nextRecurringDate(feb, 'Monthly', anchorDay: 31);
      expect(mar, DateTime(2026, 3, 31)); // recovered, no drift
    });
  });

  group('Bug 6 — clear statement balance', () {
    test('Account.copyWith can null statementBalance, else keeps it', () {
      final a = acct('c', statementBalance: 500);
      expect(a.copyWith(statementBalance: null).statementBalance, isNull);
      expect(a.copyWith(name: 'X').statementBalance, 500);
    });

    test('blanking the field on edit clears the statement balance', () {
      final card = acct(
        'c',
        balance: -100,
        nature: AccountNature.liability,
        group: 'credit',
        statementBalance: 500,
      );
      final s = LedgerState.empty()
          .copyWith(
            accounts: [card],
            editingAccountId: 'c',
            newName: 'c',
            newBalance: '100',
            newStatementBalance: '',
          )
          .saveAccount();
      expect(s.accountById('c')!.statementBalance, isNull);
    });
  });

  group('Bug 7 — non-positive fxRate guard', () {
    test('fxRate of 0 or negative falls back to the default rate', () {
      expect(
        acct('j', currency: 'JPY', fxRate: 0).rateToHkd,
        defaultRateToHkd('JPY'),
      );
      expect(
        acct('j', currency: 'JPY', fxRate: -0.05).rateToHkd,
        defaultRateToHkd('JPY'),
      );
      // …and it survives a backup round-trip (fromMap doesn't poison it).
      final restored = Account.fromMap(
        acct('j', currency: 'JPY', fxRate: 0, balance: 1000).toMap(),
      );
      expect(restored.balanceHkd, greaterThan(0));
    });
  });

  group('Bug 8 — cashForecast past-due installment', () {
    test('an in-window installment still shows when nextDate is past-due', () {
      final inst = Recurring(
        id: 'i',
        name: 'Loan',
        amount: 100,
        freq: 'Installment',
        next: 'x',
        catId: 'loan',
        kind: RecurringKind.installment,
        total: 5,
        paid: 4, // remaining 1
        accountId: 'cash',
        nextDate: DateTime(2026, 6, 1), // past-due vs the Jun 27 'now'
        startDate: DateTime(2026, 1, 1),
      );
      final s = LedgerState.empty().copyWith(
        accounts: [acct('cash', balance: 5000)],
        recurring: [inst],
      );
      final f = s.cashForecast(DateTime(2026, 6, 27), days: 30);
      expect(f.obligations.where((o) => o.name == 'Loan').length, 1);
    });
  });
}
