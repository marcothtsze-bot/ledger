import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'in_memory_repository.dart';
import 'ledger_repository.dart';
import 'sqlite_ledger_repository.dart';

/// Opens the on-device SQLite database (mobile via sqflite, desktop/tests via
/// the FFI factory) and returns a [SqliteLedgerRepository]. Falls back to an
/// in-memory repository if the database cannot be opened, so the app still runs.
Future<LedgerRepository> openLedgerRepository() async {
  try {
    final DatabaseFactory factory;
    final String dir;
    if (Platform.isAndroid || Platform.isIOS) {
      factory = sqflite.databaseFactory;
      dir = await sqflite.getDatabasesPath();
    } else {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
      dir = (await getApplicationSupportDirectory()).path;
    }
    final path = join(dir, 'ledger.db');
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: SqliteLedgerRepository.schemaVersion,
        onCreate: SqliteLedgerRepository.createSchema,
        onUpgrade: SqliteLedgerRepository.upgradeSchema,
      ),
    );
    return SqliteLedgerRepository(db);
  } on Object {
    return InMemoryLedgerRepository();
  }
}
