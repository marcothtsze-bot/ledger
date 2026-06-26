import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/data/backup.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  group('backup', () {
    test('export -> import round-trips the full snapshot', () {
      final s = LedgerState.initial()
          .setCategoryBudget('dining', 2000)
          .toSnapshot();
      final json = exportBackupJson(s);
      final back = importBackupJson(json);

      expect(back.accounts.length, s.accounts.length);
      expect(back.transactions.length, s.transactions.length);
      expect(back.categories.length, s.categories.length);
      expect(back.recurring.length, s.recurring.length);
      expect(back.incomeMonth, s.incomeMonth);
      expect(back.expenseMonth, s.expenseMonth);
      expect(back.budgets['dining'], 2000);

      // Spot-check values survive intact.
      expect(back.accounts.firstWhere((a) => a.id == 'wise').currency, 'USD');
      expect(back.transactions.first.date, s.transactions.first.date);
      expect(back.recurring.first.nextDate, s.recurring.first.nextDate);
    });

    test('restoring into LedgerState rehydrates the data', () {
      final original = LedgerState.initial().setCategoryBudget('coffee', 500);
      final restored = LedgerState.fromSnapshot(
        importBackupJson(exportBackupJson(original.toSnapshot())),
      );
      expect(restored.budgets['coffee'], 500);
      expect(restored.accounts.length, original.accounts.length);
    });

    test('non-Ledger or malformed text throws FormatException', () {
      expect(() => importBackupJson('{"hello":1}'), throwsFormatException);
      expect(() => importBackupJson('not json at all'), throwsFormatException);
    });
  });
}
