import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

/// A recurring item billed to a credit card charges that card's statement
/// directly. `citi` in the seed is a credit card (balance −8420, statement 6420).
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

  group('installment creation bills the card statement', () {
    test('a credit-card installment lands its first month on the statement', () {
      final citi = newInstallment('citi', 6).accountById('citi')!;
      expect(citi.statementBalance, 6620, reason: '6420 + 200 first month');
      expect(citi.balance, -8620, reason: '-8420 - 200');
    });

    test('an installment on a bank account leaves statementBalance null', () {
      final hsbc = newInstallment('hsbc', 6).accountById('hsbc')!;
      expect(hsbc.statementBalance, isNull);
    });
  });

  group('chargeToCard bills the next cycle to the card', () {
    test('an installment month raises the statement and advances the plan', () {
      final created = newInstallment('citi', 6);
      final plan = created.installments.first;
      final before = created.accountById('citi')!;
      final after = created.chargeToCard(plan.id);
      final citi = after.accountById('citi')!;

      expect(citi.statementBalance, before.statementBalance! + 200);
      expect(citi.balance, before.balance - 200);
      expect(after.transactions.length, created.transactions.length + 1);
      expect(after.expenseMonth, created.expenseMonth + 200);
      expect(after.recurring.firstWhere((x) => x.id == plan.id).paid, 2);
    });

    test('a subscription on a card charges the statement and rolls forward', () {
      const sub = Recurring(
        id: 's1',
        name: 'Netflix',
        amount: 78,
        freq: 'Monthly',
        next: 'Jul 1',
        catId: 'subs',
        kind: RecurringKind.sub,
        accountId: 'citi',
        nextDate: null,
      );
      final s = base.copyWith(
        recurring: [sub.copyWith(nextDate: DateTime(2026, 7, 1))],
      );
      final before = s.accountById('citi')!;
      final after = s.chargeToCard('s1');
      final citi = after.accountById('citi')!;

      expect(citi.statementBalance, before.statementBalance! + 78);
      expect(citi.balance, before.balance - 78);
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
        next: 'Jul 1',
        catId: 'health',
        kind: RecurringKind.sub,
        accountId: 'hsbc', // a bank account
      );
      final s = base.copyWith(recurring: [sub]);
      expect(identical(s.chargeToCard('s2'), s), isTrue);
    });

    test('a fully-paid installment refuses another charge', () {
      final created = newInstallment('citi', 1); // total 1, paid 1
      final plan = created.installments.first;
      final after = created.chargeToCard(plan.id);
      expect(after.toast, 'Installment plan is fully paid');
      expect(after.accountById('citi')!.balance, created.accountById('citi')!.balance);
    });
  });
}
