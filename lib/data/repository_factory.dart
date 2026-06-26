/// Picks the right [LedgerRepository] for the platform without ever importing
/// `dart:io` / sqflite into a web build: the native file is the default, and
/// the web file is swapped in when `dart.library.html` is available.
library;

export 'repository_factory_native.dart'
    if (dart.library.html) 'repository_factory_web.dart';
