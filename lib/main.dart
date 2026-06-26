import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/repository_factory.dart';
import 'state/ledger_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await openLedgerRepository();
  runApp(
    ProviderScope(
      overrides: [ledgerRepositoryProvider.overrideWithValue(repository)],
      child: const LedgerApp(),
    ),
  );
}
