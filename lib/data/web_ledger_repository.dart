import 'package:shared_preferences/shared_preferences.dart';

import 'backup.dart';
import 'ledger_repository.dart';

/// Browser-backed [LedgerRepository] for the web / installed-PWA build.
///
/// The state is small, so the whole snapshot is stored under a single key as
/// the very same JSON the Backup & Restore feature produces — no separate web
/// schema to maintain. Storage lives in the browser (localStorage via
/// `shared_preferences`), so data stays on the device and is private; the
/// in-app Backup export is the durability safety net if the browser ever
/// clears its storage.
class WebLedgerRepository implements LedgerRepository {
  WebLedgerRepository(this._prefs);

  static const String _key = 'ledger.snapshot.v1';

  final SharedPreferences _prefs;

  /// Opens the browser store. Used by the web repository factory.
  static Future<WebLedgerRepository> open() async =>
      WebLedgerRepository(await SharedPreferences.getInstance());

  @override
  Future<LedgerSnapshot?> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null; // first run → caller seeds
    try {
      return importBackupJson(raw);
    } on FormatException {
      return null; // unreadable/old data → start fresh rather than crash
    }
  }

  @override
  Future<void> persist(LedgerSnapshot snapshot) async =>
      _prefs.setString(_key, exportBackupJson(snapshot));

  @override
  Future<void> reset() async => _prefs.remove(_key);
}
