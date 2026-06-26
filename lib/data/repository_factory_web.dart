import 'in_memory_repository.dart';
import 'ledger_repository.dart';

/// Web preview build: persistence isn't wired (the app targets iOS first), so
/// run on seeded in-memory data. Native builds use the SQLite implementation.
Future<LedgerRepository> openLedgerRepository() async =>
    InMemoryLedgerRepository();
