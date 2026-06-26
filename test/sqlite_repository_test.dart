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

  test('upgrades a v4 database to v6 (adds icon column + categories table)',
      () async {
    // Open at the OLD schema (v4: no accounts.icon, no categories table).
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 4, onCreate: _createV4Schema),
    );
    addTearDown(db.close);

    await db.insert('accounts', {
      'id': 'hsbc',
      'name': 'HSBC One',
      'sub': 'Debit · HKD',
      'letter': 'H',
      'color': '#3ad29f',
      'bg': '#1f3a32',
      'balance': 100.0,
      'nature': 'asset',
      'grp': 'cashbank',
      'pinned': 1,
    });

    // Run the real migration to the current version.
    await SqliteLedgerRepository.upgradeSchema(
      db,
      4,
      SqliteLedgerRepository.schemaVersion,
    );

    final loaded = await SqliteLedgerRepository(db).load();
    expect(loaded, isNotNull);
    expect(loaded!.accounts.single.id, 'hsbc');
    expect(loaded.accounts.single.icon, isNull, reason: 'new icon col defaults null');
    expect(
      loaded.categories.length,
      kCategories.length,
      reason: 'empty categories table falls back to the seed set',
    );
  });
}

/// Builds the pre-v5 (version 4) schema so the upgrade path can be tested:
/// accounts has no `icon` column and there is no `categories` table.
Future<void> _createV4Schema(Database db, int version) async {
  await db.execute('''
    CREATE TABLE accounts(
      id TEXT PRIMARY KEY, name TEXT, sub TEXT, letter TEXT,
      color TEXT, bg TEXT, balance REAL, nature TEXT, grp TEXT,
      note TEXT, creditLimit REAL, minPayment REAL,
      statementDay INTEGER, dueDay INTEGER, statementBalance REAL,
      pinned INTEGER
    )''');
  await db.execute('''
    CREATE TABLE txns(
      id INTEGER PRIMARY KEY, type TEXT, amount REAL, payee TEXT,
      catId TEXT, acctId TEXT, day TEXT, fx TEXT, toAcctId TEXT
    )''');
  await db.execute('''
    CREATE TABLE recurring(
      id TEXT PRIMARY KEY, name TEXT, amount REAL, freq TEXT, next TEXT,
      catId TEXT, kind TEXT, total INTEGER, paid INTEGER
    )''');
  await db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v REAL)');
}
