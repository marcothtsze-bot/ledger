import 'ledger_repository.dart';

/// Volatile [LedgerRepository] kept entirely in memory. Used by widget/unit
/// tests and as a safe fallback if the on-device database fails to open.
class InMemoryLedgerRepository implements LedgerRepository {
  LedgerSnapshot? _snapshot;

  InMemoryLedgerRepository([this._snapshot]);

  @override
  Future<LedgerSnapshot?> load() async => _snapshot;

  @override
  Future<void> persist(LedgerSnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<void> reset() async => _snapshot = null;
}
