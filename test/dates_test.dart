import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/core/statement.dart';

void main() {
  group('day labels', () {
    final today = DateTime(2026, 6, 26);

    test('today / yesterday / older', () {
      expect(dayLabel(DateTime(2026, 6, 26, 9, 30), today), 'Today');
      expect(dayLabel(DateTime(2026, 6, 25), today), 'Yesterday');
      expect(dayLabel(DateTime(2026, 6, 21), today), 'Jun 21');
    });

    test('compactDate', () {
      expect(compactDate(DateTime(2026, 6, 26)), '26 Jun 2026');
    });
  });
}
