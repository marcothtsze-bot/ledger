import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

/// The multi-month forward forecast and creating a monthly payment with an end
/// date. `citi` (seed) is a credit card: statementDay 5, dueDay 25.
void main() {
  final base = LedgerState.initial();

  group('upcomingStatements projects charges onto future statements', () {
    final now = DateTime(2026, 6, 20);
    // 5 installment months left (Jul 1 … Nov 1) + an ongoing monthly sub.
    final s = base.copyWith(
      recurring: [
        const Recurring(
          id: 'inst',
          name: 'MacBook',
          amount: 200,
          freq: 'Installment',
          next: 'x',
          catId: 'shopping',
          kind: RecurringKind.installment,
          total: 6,
          paid: 1,
          accountId: 'citi',
        ).copyWith(nextDate: DateTime(2026, 7, 1)),
        const Recurring(
          id: 'sub',
          name: 'Netflix',
          amount: 78,
          freq: 'Monthly',
          next: 'x',
          catId: 'subs',
          kind: RecurringKind.sub,
          accountId: 'citi',
        ).copyWith(nextDate: DateTime(2026, 7, 2)),
      ],
    );

    test('first statement closes Jul 5, due Jul 25, totals both charges', () {
      final stmts = s.upcomingStatements('citi', now, cycles: 6);
      expect(stmts.first.close, DateTime(2026, 7, 5));
      expect(stmts.first.due, DateTime(2026, 7, 25));
      expect(stmts.first.total, 278); // 200 installment + 78 sub
      expect(stmts.first.charges.length, 2);
    });

    test('the installment drops off once its run ends, the sub continues', () {
      final stmts = s.upcomingStatements('citi', now, cycles: 6);
      expect(stmts.length, 6);
      // Installment hits cycles 0–4 (5 months left); cycle 5 is sub only.
      expect(stmts.last.total, 78);
      expect(stmts.last.charges.single.source.id, 'sub');
    });
  });

  group('creating a monthly payment with an end date', () {
    LedgerState scheduleMonthly({DateTime? end}) => base
        .copyWith(
          sheetOpen: true,
          txnType: TxnType.expense,
          amount: '50',
          payee: 'Gym',
          accountId: 'hsbc',
          categoryId: 'health',
          repeat: RepeatMode.monthly,
          txnDate: DateTime(2026, 7, 1),
          recurEnd: end,
        )
        .save(close: true);

    test('records start (first charge) and the chosen end date', () {
      final r = scheduleMonthly(end: DateTime(2026, 12, 31));
      final sched = r.recurring.first;
      expect(sched.startDate, DateTime(2026, 7, 1));
      expect(sched.endDate, DateTime(2026, 12, 31));
      expect(r.recurEnd, isNull, reason: 'draft end date resets after saving');
    });

    test('no end date means ongoing', () {
      expect(scheduleMonthly().recurring.first.endDate, isNull);
    });
  });
}
