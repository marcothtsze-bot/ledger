import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_state.dart';

/// Subscriptions/installments get start & end dates, and a credit card can show
/// what's already committed to its next statement (so you don't over-spend).
void main() {
  Recurring sub(
    String id, {
    required double amount,
    required String accountId,
    DateTime? nextDate,
    DateTime? endDate,
    RecurringKind kind = RecurringKind.sub,
    int? total,
    int? paid,
  }) => Recurring(
    id: id,
    name: id,
    amount: amount,
    freq: kind == RecurringKind.installment ? 'Installment' : 'Monthly',
    next: 'next',
    catId: 'subs',
    kind: kind,
    total: total,
    paid: paid,
    accountId: accountId,
    nextDate: nextDate,
    endDate: endDate,
  );

  group('Recurring start/end dates', () {
    test('round-trip through toMap/fromMap', () {
      final r = sub(
        'x',
        amount: 1,
        accountId: 'citi',
        nextDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 12, 31),
      ).copyWith(startDate: DateTime(2026, 1, 1));
      final back = Recurring.fromMap(r.toMap());
      expect(back.startDate, DateTime(2026, 1, 1));
      expect(back.endDate, DateTime(2026, 12, 31));
    });

    test('copyWith preserves endDate unless explicitly changed', () {
      final r = sub('x', amount: 1, accountId: 'citi', endDate: DateTime(2026, 12, 31));
      expect(r.copyWith(name: 'Z').endDate, DateTime(2026, 12, 31)); // kept
      expect(r.copyWith(endDate: null).endDate, isNull); // cleared
      expect(
        r.copyWith(endDate: DateTime(2027, 1, 1)).endDate,
        DateTime(2027, 1, 1),
      );
    });
  });

  group('editRecurring end date', () {
    final base = LedgerState.initial().copyWith(
      recurring: [sub('s', amount: 78, accountId: 'citi')],
    );

    test('sets, clears, and preserves the end date', () {
      final withEnd = base.editRecurring('s', endDate: DateTime(2026, 12, 31));
      expect(withEnd.recurring.first.endDate, DateTime(2026, 12, 31));

      final cleared = withEnd.editRecurring('s', endDate: null);
      expect(cleared.recurring.first.endDate, isNull);

      final kept = withEnd.editRecurring('s', name: 'Renamed');
      expect(kept.recurring.first.endDate, DateTime(2026, 12, 31),
          reason: 'omitting endDate leaves it untouched');
    });
  });

  group('commitmentsForNextStatement', () {
    // citi: credit card, statementDay 5 → next close after Jun 20 is Jul 5.
    final now = DateTime(2026, 6, 20);
    final s = LedgerState.initial().copyWith(
      recurring: [
        sub('A', amount: 78, accountId: 'citi', nextDate: DateTime(2026, 6, 25)),
        sub('B', amount: 58, accountId: 'citi', nextDate: DateTime(2026, 7, 10)),
        sub('C', amount: 200, accountId: 'citi', nextDate: DateTime(2026, 7, 1),
            kind: RecurringKind.installment, total: 6, paid: 1),
        sub('D', amount: 300, accountId: 'citi', nextDate: DateTime(2026, 7, 1),
            kind: RecurringKind.installment, total: 6, paid: 6),
        sub('E', amount: 99, accountId: 'citi', nextDate: DateTime(2026, 6, 25),
            endDate: DateTime(2026, 6, 1)),
        sub('F', amount: 400, accountId: 'hsbc', nextDate: DateTime(2026, 6, 25)),
      ],
    );

    test('includes only card charges due before the next close', () {
      final ids = s.commitmentsForNextStatement('citi', now).map((r) => r.id);
      expect(ids.toSet(), {'A', 'C'},
          reason: 'B is after close; D is finished; E ended; F is off-card');
      expect(s.committedToNextStatement('citi', now), 278); // 78 + 200
    });

    test('a non-card account commits nothing', () {
      expect(s.commitmentsForNextStatement('hsbc', now), isEmpty);
      expect(s.committedToNextStatement('hsbc', now), 0);
    });
  });
}
