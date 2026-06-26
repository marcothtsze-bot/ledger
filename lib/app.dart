import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'overlays/account_detail_overlay.dart';
import 'overlays/recurring_overlay.dart';
import 'screens/accounts_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'sheets/add_account_sheet.dart';
import 'sheets/add_transaction_sheet.dart';
import 'sheets/pay_statement_sheet.dart';
import 'state/ledger_notifier.dart';
import 'state/ledger_state.dart';
import 'theme/tokens.dart';
import 'widgets/tab_bar.dart';
import 'widgets/toast.dart';

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ledger',
      debugShowCheckedModeBanner: false,
      theme: buildLedgerTheme(),
      home: const LedgerShell(),
    );
  }
}

/// The single phone canvas: the active tab screen, the persistent tab bar, and
/// any overlays / sheets / toast layered on top (matching the prototype's
/// z-order).
class LedgerShell extends ConsumerWidget {
  const LedgerShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);

    final layers = <Widget>[
      Positioned.fill(
        child: IndexedStack(
          index: s.tab.index,
          children: const [
            HomeScreen(),
            AccountsScreen(),
            ActivityScreen(),
            InsightsScreen(),
          ],
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: LedgerTabBar(active: s.tab, onTab: n.goTab, onAdd: n.openSheet),
      ),
      if (s.overlay == LedgerOverlay.recurring)
        const Positioned.fill(child: RecurringOverlay()),
      if (s.overlay == LedgerOverlay.account)
        const Positioned.fill(child: AccountDetailOverlay()),
      if (s.acctSheetOpen) const Positioned.fill(child: AddAccountSheet()),
      if (s.payCardId.isNotEmpty)
        const Positioned.fill(child: PayStatementSheet()),
      if (s.sheetOpen) const Positioned.fill(child: AddTransactionSheet()),
      if (s.toast.isNotEmpty)
        Positioned(
          bottom: 104,
          left: 0,
          right: 0,
          child: Center(child: LedgerToast(s.toast)),
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.screen,
      resizeToAvoidBottomInset: false,
      body: PhoneFrame(child: Stack(children: layers)),
    );
  }
}

/// Fills the screen on a real phone; on a wide screen (web/desktop preview) it
/// centres a 393×812 device mock so the design reads as intended.
class PhoneFrame extends StatelessWidget {
  final Widget child;
  const PhoneFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 520) return child;
    return ColoredBox(
      color: const Color(0xFFD9D7D0),
      child: Center(
        child: Container(
          width: 393,
          height: 812,
          decoration: BoxDecoration(
            color: const Color(0xFF05100C),
            borderRadius: BorderRadius.circular(AppRadii.bezel),
            boxShadow: AppShadows.device,
          ),
          padding: const EdgeInsets.all(11),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.device),
            child: child,
          ),
        ),
      ),
    );
  }
}
