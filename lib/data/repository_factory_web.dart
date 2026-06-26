import 'ledger_repository.dart';
import 'web_ledger_repository.dart';

/// Web / installed-PWA build: persist to the browser's local storage so data
/// survives reloads and app restarts, just like the native SQLite build. Native
/// builds use the SQLite implementation (see `repository_factory_native.dart`).
Future<LedgerRepository> openLedgerRepository() async =>
    WebLedgerRepository.open();
