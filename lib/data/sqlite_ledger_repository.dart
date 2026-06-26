import 'package:sqflite_common/sqlite_api.dart';

import '../models/account.dart';
import '../models/recurring.dart';
import '../models/txn.dart';
import 'ledger_repository.dart';
import 'seed.dart';

/// On-device persistence backed by SQLite (via sqflite).
///
/// The whole state is small, so [persist] writes a fresh snapshot inside one
/// transaction (clear + bulk insert). Takes an already-open [Database] so the
/// platform (mobile sqflite vs. ffi in tests/desktop) is chosen by the caller.
class SqliteLedgerRepository implements LedgerRepository {
  final Database db;

  SqliteLedgerRepository(this.db);

  static const int schemaVersion = 4;

  /// Creates the tables. Pass this as `onCreate` when opening the database.
  static Future<void> createSchema(Database db, int version) async {
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

  /// Adds columns introduced after v1. Pass this as `onUpgrade`.
  static Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE accounts ADD COLUMN statementDay INTEGER');
      await db.execute('ALTER TABLE accounts ADD COLUMN dueDay INTEGER');
      await db.execute('ALTER TABLE accounts ADD COLUMN statementBalance REAL');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE txns ADD COLUMN toAcctId TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE accounts ADD COLUMN pinned INTEGER');
    }
  }

  @override
  Future<LedgerSnapshot?> load() async {
    final accRows = await db.query('accounts');
    if (accRows.isEmpty) return null;

    final accounts = accRows.map(Account.fromMap).toList();
    final txnRows = await db.query('txns');
    final transactions = txnRows
        .map((r) => Txn.fromMap({...r, 'foreign': r['fx']}))
        .toList();
    final recRows = await db.query('recurring');
    final recurring = recRows.map(Recurring.fromMap).toList();

    final metaRows = await db.query('meta');
    var income = kSeedIncomeMonth, expense = kSeedExpenseMonth;
    for (final row in metaRows) {
      final v = (row['v'] as num?)?.toDouble() ?? 0;
      if (row['k'] == 'incomeMonth') income = v;
      if (row['k'] == 'expenseMonth') expense = v;
    }

    return LedgerSnapshot(
      accounts: accounts,
      transactions: transactions,
      recurring: recurring,
      incomeMonth: income,
      expenseMonth: expense,
    );
  }

  @override
  Future<void> persist(LedgerSnapshot snapshot) async {
    await db.transaction((txn) async {
      await txn.delete('accounts');
      await txn.delete('txns');
      await txn.delete('recurring');
      await txn.delete('meta');

      final batch = txn.batch();
      for (final a in snapshot.accounts) {
        batch.insert('accounts', a.toMap());
      }
      for (final t in snapshot.transactions) {
        final row = t.toMap()..['fx'] = t.foreign;
        row.remove('foreign');
        batch.insert('txns', row);
      }
      for (final r in snapshot.recurring) {
        batch.insert('recurring', r.toMap());
      }
      batch.insert('meta', {'k': 'incomeMonth', 'v': snapshot.incomeMonth});
      batch.insert('meta', {'k': 'expenseMonth', 'v': snapshot.expenseMonth});
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> reset() async {
    await db.transaction((txn) async {
      await txn.delete('accounts');
      await txn.delete('txns');
      await txn.delete('recurring');
      await txn.delete('meta');
    });
  }
}
