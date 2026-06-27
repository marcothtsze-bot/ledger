import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ledger/app.dart';
import 'package:ledger/data/in_memory_repository.dart';
import 'package:ledger/models/enums.dart';
import 'package:ledger/models/recurring.dart';
import 'package:ledger/state/ledger_notifier.dart';
import 'package:ledger/state/ledger_state.dart';

/// Regression: an installment plan must be manageable. It used to render as a
/// dead card in the Recurring screen with no way to edit or cancel it.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      original?.call(details);
    };
  });

  const plan = Recurring(
    id: 'u1',
    name: 'MacBook',
    amount: 1500,
    freq: 'Installment',
    next: 'Jul 21',
    catId: 'shopping',
    kind: RecurringKind.installment,
    total: 12,
    paid: 1,
    accountId: 'hsbc',
  );

  testWidgets('an installment plan opens its manage sheet from Recurring', (
    tester,
  ) async {
    final repo = InMemoryLedgerRepository(
      LedgerState.initial().copyWith(recurring: [plan]).toSnapshot(),
    );
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
        child: const LedgerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Open the Recurring screen from the Home "Upcoming → Manage" action.
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    // The plan's progress row only exists inside the Recurring overlay, so its
    // presence proves the screen opened and the installment rendered.
    expect(find.text('1 of 12 months'), findsOneWidget);

    // Tapping the plan row (was a dead container) opens the manage sheet,
    // worded for an installment rather than a subscription.
    await tester.tap(find.text('1 of 12 months'));
    await tester.pumpAndSettle();
    expect(find.text('Edit installment'), findsOneWidget);
    expect(find.text('Cancel plan'), findsOneWidget);
  });
}
