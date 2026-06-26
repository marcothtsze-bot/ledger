import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/core/statement.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  group('monthGridCells', () {
    test('lists 1..daysInMonth after Sunday-first leading blanks', () {
      final cells = monthGridCells(2026, 6); // June 2026
      final lead = DateTime(2026, 6, 1).weekday % 7; // Sunday-first offset
      expect(cells.take(lead), everyElement(isNull));
      expect(cells[lead], 1);
      expect(cells.whereType<int>().toList(), List.generate(30, (i) => i + 1));
    });

    test('leading blanks equal the Sunday-first weekday of the 1st', () {
      for (final m in [1, 2, 7, 12]) {
        final cells = monthGridCells(2026, m);
        final lead = cells.indexWhere((c) => c != null);
        expect(lead, DateTime(2026, m, 1).weekday % 7);
      }
    });

    test('handles February leap vs non-leap years', () {
      expect(monthGridCells(2024, 2).whereType<int>().last, 29);
      expect(monthGridCells(2026, 2).whereType<int>().last, 28);
    });
  });

  group('pickDate', () {
    test('sets the drafted txn date and closes the picker', () {
      final s = LedgerState.initial().copyWith(picker: ActivePicker.date);
      final picked = DateTime(2026, 3, 14);
      final next = s.pickDate(picked);
      expect(next.txnDate, picked);
      expect(next.picker, ActivePicker.none);
    });
  });
}
