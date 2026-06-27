import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/core/statement.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

/// A recurring item billed to a credit card raises what's owed — which lands on
/// the NEXT statement (pending), NOT the current/closed statement balance.
/// `citi` (seed) is a credit card: balance −8420, statementBalance 6420.
void main() {
  final base = LedgerState.initial();

  LedgerState newInstallment(String accountId, int months) => base
      .copyWith(
        txnType: TxnType.expense,
        accountId: accountId,
        categoryId: 'shopping',
        amount: '1200',
        installMonths: months,
        repeat: RepeatMode.installment,
      )
      .save(close: true);

  group('a card charge lands on the next statement, not the current one', () {
    test('an installment raises pending and leaves the closed statement', () {
      final citi = newInstallment('citi', 6).accountById('citi')!;
      expect(citi.balance, -8620, reason: '-8420 - 200 owed');
      expect(citi.statementBalance, 6420, reason: 'current statement untouched');
      expect(
        pendingThisCycle(citi.balance, citi.statementBalance),
        2200, // was 2000, + 200 from the new charge → next statement
      );
    });

    test('an installment on a bank account has no statement', () {
      expect(
        newInstallment('hsbc', 6).accountById('hsbc')!.statementBalance,
        isNull,
      );
    });
  });

  group('chargeToCard bills the next cycle', () {
    test('an installment month raises what is owed and advances', () {
      final created = newInstallment('citi', 6);
      final plan = created.installments.first;
      final before = created.accountById('citi')!;
      final after = created.chargeToCard(plan.id);
      final citi = after.accountById('citi')!;

      expect(citi.balance, before.balance - 200);
      expect(citi.statementBalance, before.statementBalance);
      expect(after.transactions.length, created.transactions.length + 1);
      expect(after.recurring.firstWhere((x) => x.id == plan.id).paid, 2);
    });

    test('a subscription on a card is charged and rolls forward', () {
      const sub = Recurring(
        id: 's1',
        name: 'Netflix',
        amount: 78,
        freq: 'Monthly',
        next: 'x',
        catId: 'subs',
        kind: RecurringKind.sub,
        accountId: 'citi',
      );
      final s = base.copyWith(
        recurring: [sub.copyWith(nextDate: DateTime(2026, 7, 1))],
      );
      final before = s.accountById('citi')!;
      final after = s.chargeToCard('s1');
      final citi = after.accountById('citi')!;
      expect(citi.balance, before.balance - 78);
      expect(citi.statementBalance, before.statementBalance);
      expect(after.transactions.first.payee, 'Netflix');
      expect(
        after.recurring.firstWhere((x) => x.id == 's1').nextDate,
        DateTime(2026, 8, 1),
      );
    });

    test('it is a no-op when the recurring is not billed to a card', () {
      const sub = Recurring(
        id: 's2',
        name: 'Gym',
        amount: 300,
        freq: 'Monthly',
        next: 'x',
        catId: 'health',
        kind: RecurringKind.sub,
        accountId: 'hsbc',
      );
      final s = base.copyWith(recurring: [sub]);
      expect(identical(s.chargeToCard('s2'), s), isTrue);
    });

    test('a fully-paid installment refuses another charge', () {
      final created = newInstallment('citi', 1);
      final plan = created.installments.first;
      expect(
        created.chargeToCard(plan.id).toast,
        'Installment plan is fully paid',
      );
    });
  });
}
