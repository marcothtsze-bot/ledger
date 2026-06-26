import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/data/in_memory_repository.dart';
import 'package:ledger/data/seed.dart';
import 'package:ledger/state/ledger_state.dart';

void main() {
  group('InMemoryLedgerRepository', () {
    test('load returns null before anything is persisted', () async {
      final repo = InMemoryLedgerRepository();
      expect(await repo.load(), isNull);
    });

    test('persist then load returns the same snapshot', () async {
      final repo = InMemoryLedgerRepository();
      await repo.persist(LedgerState.initial().toSnapshot());
      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.accounts.length, 6);
      expect(loaded.transactions.length, 5);
      expect(loaded.incomeMonth, kSeedIncomeMonth);
      expect(loaded.expenseMonth, kSeedExpenseMonth);
    });

    test('reset clears persisted data', () async {
      final repo = InMemoryLedgerRepository();
      await repo.persist(LedgerState.initial().toSnapshot());
      await repo.reset();
      expect(await repo.load(), isNull);
    });
  });
}
