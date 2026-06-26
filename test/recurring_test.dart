import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/core/statement.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  group('Recurring model', () {
    test('round-trips icon, color, accountId and nextDate', () {
      final r = Recurring(
        id: 'r1',
        name: 'Netflix',
        amount: 78,
        freq: 'Monthly',
        next: 'Jun 24',
        catId: 'subs',
        kind: RecurringKind.sub,
        icon: 'movie',
        color: '#e50914',
        accountId: 'hsbc',
        nextDate: DateTime(2026, 6, 24),
      );
      final back = Recurring.fromMap(r.toMap());
      expect(back.icon, 'movie');
      expect(back.color, '#e50914');
      expect(back.accountId, 'hsbc');
      expect(back.nextDate, DateTime(2026, 6, 24));
    });

    test('new fields default to null when absent', () {
      const r = Recurring(
        id: 'r0',
        name: 'X',
        amount: 10,
        freq: 'Monthly',
        next: 'Jul 1',
        catId: 'subs',
        kind: RecurringKind.sub,
      );
      final back = Recurring.fromMap(r.toMap());
      expect(back.icon, isNull);
      expect(back.color, isNull);
      expect(back.accountId, isNull);
      expect(back.nextDate, isNull);
    });
  });

  group('recurring CRUD on LedgerState', () {
    final base = LedgerState.initial();

    test('editRecurring updates fields in place by id', () {
      final next = base.editRecurring(
        'r1',
        name: 'Netflix Premium',
        amount: 98,
        icon: 'smart_display',
        color: '#e50914',
        accountId: 'citi',
      );
      final r = next.recurring.firstWhere((x) => x.id == 'r1');
      expect(r.name, 'Netflix Premium');
      expect(r.amount, 98);
      expect(r.icon, 'smart_display');
      expect(r.color, '#e50914');
      expect(r.accountId, 'citi');
    });

    test('deleteRecurring cancels (removes) the subscription', () {
      expect(base.recurring.any((r) => r.id == 'r1'), isTrue);
      final next = base.deleteRecurring('r1');
      expect(next.recurring.any((r) => r.id == 'r1'), isFalse);
    });
  });

  group('nextRecurringDate', () {
    test('advances monthly with day clamping and weekly by 7 days', () {
      expect(nextRecurringDate(DateTime(2026, 6, 24), 'Monthly'),
          DateTime(2026, 7, 24));
      expect(nextRecurringDate(DateTime(2026, 1, 31), 'Monthly'),
          DateTime(2026, 2, 28)); // clamps to month length
      expect(nextRecurringDate(DateTime(2026, 6, 24), 'Weekly'),
          DateTime(2026, 7, 1));
    });
  });

  group('pay / settle / due', () {
    final base = LedgerState.initial();

    test('payRecurring records an expense and advances the next date', () {
      final s0 = base.editRecurring('r1',
          nextDate: DateTime(2026, 6, 24), accountId: 'hsbc');
      final hsbcBefore = s0.accountById('hsbc')!.balance;
      final txnsBefore = s0.transactions.length;

      final s1 = s0.payRecurring('r1', 'hsbc');
      expect(s1.transactions.length, txnsBefore + 1);
      expect(s1.accountById('hsbc')!.balance, hsbcBefore - 78); // Netflix 78
      expect(s1.recurring.firstWhere((r) => r.id == 'r1').nextDate,
          DateTime(2026, 7, 24));
    });

    test('settleRecurring advances the date with no transaction', () {
      final s0 = base.editRecurring('r1', nextDate: DateTime(2026, 6, 24));
      final txnsBefore = s0.transactions.length;
      final hsbcBefore = s0.accountById('hsbc')!.balance;

      final s1 = s0.settleRecurring('r1');
      expect(s1.transactions.length, txnsBefore); // nothing recorded
      expect(s1.accountById('hsbc')!.balance, hsbcBefore); // balance untouched
      expect(s1.recurring.firstWhere((r) => r.id == 'r1').nextDate,
          DateTime(2026, 7, 24));
    });

    test('a monthly Repeat schedules Upcoming without posting a transaction', () {
      final s = LedgerState.initial().copyWith(
        sheetOpen: true,
        txnType: TxnType.expense,
        amount: '120',
        accountId: 'hsbc',
        categoryId: 'subs',
        repeat: RepeatMode.monthly,
        txnDate: DateTime(2026, 7, 10),
      );
      final hsbcBefore = s.accountById('hsbc')!.balance;
      final txnsBefore = s.transactions.length;
      final recBefore = s.recurring.length;
      final expBefore = s.expenseMonth;

      final next = s.save(close: true);
      expect(next.transactions.length, txnsBefore, reason: 'nothing posted');
      expect(next.accountById('hsbc')!.balance, hsbcBefore,
          reason: 'balance untouched');
      expect(next.expenseMonth, expBefore, reason: 'month totals untouched');
      expect(next.recurring.length, recBefore + 1, reason: 'scheduled');
      expect(next.recurring.first.nextDate, DateTime(2026, 7, 10));
    });

    test('dueRecurring lists items whose nextDate is today or earlier', () {
      final today = DateTime(2026, 6, 26);
      final s0 = base
          .editRecurring('r1', nextDate: DateTime(2026, 6, 26)) // due today
          .editRecurring('r2', nextDate: DateTime(2026, 6, 20)) // overdue
          .editRecurring('r3', nextDate: DateTime(2026, 7, 2)); // future
      final due = s0.dueRecurring(today).map((r) => r.id).toSet();
      expect(due.contains('r1'), isTrue);
      expect(due.contains('r2'), isTrue);
      expect(due.contains('r3'), isFalse);
    });
  });
}
