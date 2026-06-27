import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/data/ledger_repository.dart';
import 'package:ledger/data/seed.dart';
import 'package:ledger/models/account.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

/// Fixes from the Codex × Claude review pass.
void main() {
  final base = LedgerState.initial();

  Recurring rec(
    String id, {
    required RecurringKind kind,
    required String accountId,
    DateTime? nextDate,
    DateTime? endDate,
    int? total,
    int? paid,
    double amount = 50,
  }) => Recurring(
    id: id,
    name: id,
    amount: amount,
    freq: kind == RecurringKind.installment ? 'Installment' : 'Monthly',
    next: 'x',
    catId: kind == RecurringKind.installment ? 'shopping' : 'subs',
    kind: kind,
    total: total,
    paid: paid,
    accountId: accountId,
    nextDate: nextDate,
    endDate: endDate,
  );

  group('ended / finished recurring stop being due or chargeable', () {
    final after = DateTime(2026, 7, 2);
    final endedSub = rec('e', kind: RecurringKind.sub, accountId: 'citi',
        nextDate: DateTime(2026, 7, 1), endDate: DateTime(2026, 6, 1));
    final doneInstallment = rec('d', kind: RecurringKind.installment,
        accountId: 'citi', nextDate: DateTime(2026, 7, 1), total: 6, paid: 6);

    test('an ended subscription drops from due + upcoming', () {
      final s = base.copyWith(recurring: [endedSub]);
      expect(s.dueRecurring(after).where((r) => r.id == 'e'), isEmpty);
      expect(s.upcomingRecurring(after).where((r) => r.id == 'e'), isEmpty);
    });

    test('a finished installment drops from due + upcoming', () {
      final s = base.copyWith(recurring: [doneInstallment]);
      expect(s.dueRecurring(after).where((r) => r.id == 'd'), isEmpty);
      expect(s.upcomingRecurring(after).where((r) => r.id == 'd'), isEmpty);
    });

    test('payRecurring is a no-op for an ended subscription', () {
      final s = base.copyWith(recurring: [endedSub]);
      expect(identical(s.payRecurring('e', 'hsbc'), s), isTrue);
    });

    test('chargeToCard refuses ended / finished items', () {
      expect(
        base.copyWith(recurring: [endedSub]).chargeToCard('e').toast,
        'e has ended',
      );
      expect(
        base.copyWith(recurring: [doneInstallment]).chargeToCard('d').toast,
        'Installment plan is fully paid',
      );
    });
  });

  group('account-id heal never steals a real id', () {
    Account acct(String id, String name) => Account(
      id: id,
      name: name,
      sub: '',
      letter: name[0],
      color: '#fff',
      bg: '#000',
      balance: 0,
      nature: AccountNature.asset,
      group: 'cashbank',
    );

    test('[a1, a1, a1-2] keeps the genuine a1-2 account', () {
      final snap = LedgerSnapshot(
        accounts: [acct('a1', 'B'), acct('a1', 'C'), acct('a1-2', 'D')],
        transactions: const [],
        recurring: const [],
        categories: kCategories,
        budgets: const {},
        incomeMonth: 0,
        expenseMonth: 0,
      );
      final s = LedgerState.fromSnapshot(snap);
      final idByName = {for (final a in s.accounts) a.name: a.id};

      expect(s.accounts.length, 3);
      expect(s.accounts.map((a) => a.id).toSet().length, 3);
      expect(idByName['D'], 'a1-2', reason: 'the real a1-2 keeps its id');
      expect(idByName['B'], 'a1');
      expect(idByName['C'], isNot('a1-2'), reason: 'the dup dodged it');
    });
  });

  group('exchange rate must be positive', () {
    LedgerState addJpy(String rate) => LedgerState.empty()
        .copyWith(
          newName: 'JP',
          newType: 'Debit',
          newCurrency: 'JPY',
          newFxRate: rate,
          newBalance: '1000',
        )
        .saveAccount();

    test('zero or negative rate falls back to the default (null)', () {
      expect(addJpy('0').accounts.last.fxRate, isNull);
      expect(addJpy('-5').accounts.last.fxRate, isNull);
    });

    test('a positive rate is kept', () {
      expect(addJpy('0.05').accounts.last.fxRate, 0.05);
    });
  });
}
