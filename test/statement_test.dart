import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/core/statement.dart';

void main() {
  group('statement helpers', () {
    test('ordinalDay', () {
      expect(ordinalDay(1), '1st');
      expect(ordinalDay(2), '2nd');
      expect(ordinalDay(3), '3rd');
      expect(ordinalDay(5), '5th');
      expect(ordinalDay(11), '11th');
      expect(ordinalDay(21), '21st');
      expect(ordinalDay(22), '22nd');
      expect(ordinalDay(25), '25th');
    });

    test('nextDueLabel rolls forward once the day has passed', () {
      expect(nextDueLabel(25, DateTime(2026, 6, 26)), 'Jul 25');
      expect(nextDueLabel(25, DateTime(2026, 6, 20)), 'Jun 25');
      expect(
        nextDueLabel(25, DateTime(2026, 6, 25)),
        'Jun 25',
        reason: 'due today',
      );
    });

    test('nextDueLabel clamps to month length', () {
      expect(nextDueLabel(31, DateTime(2026, 2, 10)), 'Feb 28');
      expect(nextDueLabel(31, DateTime(2026, 1, 31)), 'Jan 31');
    });

    test('nextDueLabel rolls into the next year', () {
      expect(nextDueLabel(5, DateTime(2026, 12, 26)), 'Jan 5');
    });

    test('pendingThisCycle = total owed − statement, floored at 0', () {
      expect(pendingThisCycle(-8420, 6420), 2000);
      expect(pendingThisCycle(-8420, null), 8420);
      expect(pendingThisCycle(-5000, 6420), 0);
    });
  });
}
