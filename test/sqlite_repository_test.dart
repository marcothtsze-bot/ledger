import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/data/seed.dart';
import 'package:ledger/data/sqlite_ledger_repository.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/state/ledger_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the real on-device persistence path (the SQLite mapping, the `fx`
/// column rename, the meta table) against an in-memory SQLite database.
void main() {
  setUpAll(sqfliteFfiInit);

  test('SQLite repository round-trips the seeded snapshot', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: SqliteLedgerRepository.schemaVersion,
        onCreate: SqliteLedgerRepository.createSchema,
      ),
    );
    addTearDown(db.close);
    final repo = SqliteLedgerRepository(db);

    expect(await repo.load(), isNull, reason: 'empty DB before first persist');

    await repo.persist(LedgerState.initial().toSnapshot());
    final loaded = await repo.load();

    expect(loaded, isNotNull);
    expect(loaded!.accounts.length, 6);
    expect(loaded.transactions.length, 5);
    expect(loaded.incomeMonth, kSeedIncomeMonth);
    expect(loaded.expenseMonth, kSeedExpenseMonth);

    final citi = loaded.accounts.firstWhere((a) => a.id == 'citi');
    expect(citi.balance, -8420);
    expect(citi.nature, AccountNature.liability);
    expect(citi.creditLimit, 80000);

    final amazon = loaded.transactions.firstWhere(
      (t) => t.payee == 'Amazon US',
    );
    expect(amazon.foreign, 'US\$48.00 @ 7.81', reason: 'fx column survives');

    await repo.reset();
    expect(await repo.load(), isNull);
  });
}
