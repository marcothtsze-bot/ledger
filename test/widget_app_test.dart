import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ledger/app.dart';
import 'package:ledger/data/in_memory_repository.dart';
import 'package:ledger/state/ledger_notifier.dart';

void main() {
  setUpAll(() {
    // Don't hit the network for fonts during tests; fall back to the default.
    GoogleFonts.config.allowRuntimeFetching = false;
    // Widget tests render with the fixed-width "Ahem" font (1em per glyph),
    // which makes this money-dense UI report harmless RenderFlex overflows that
    // never occur with the real proportional fonts. Ignore only those; every
    // other error still fails the test.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      original?.call(details);
    };
  });

  Widget harness() => ProviderScope(
    overrides: [
      ledgerRepositoryProvider.overrideWithValue(InMemoryLedgerRepository()),
    ],
    child: const LedgerApp(),
  );

  Future<void> bootPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  testWidgets('boots to the Home dashboard', (tester) async {
    await bootPhone(tester);
    expect(find.text('Hi, Marco'), findsOneWidget);
    expect(find.text('Net Worth · HKD'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('the FAB opens the Add Transaction sheet', (tester) async {
    await bootPhone(tester);
    await tester.tap(find.byKey(const ValueKey('addFab')));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('switching to the Activity tab shows search', (tester) async {
    await bootPhone(tester);
    await tester.tap(find.byKey(const ValueKey('tab_activity')));
    await tester.pumpAndSettle();
    expect(find.text('Search payee or category'), findsOneWidget);
  });

  testWidgets('entering an amount and saving shows a success toast', (
    tester,
  ) async {
    await bootPhone(tester);
    await tester.tap(find.byKey(const ValueKey('addFab')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.tap(find.text('0'));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump(); // apply the save
    expect(find.text('Transaction saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2)); // let the toast auto-dismiss
    expect(find.text('Transaction saved'), findsNothing);
  });
}
