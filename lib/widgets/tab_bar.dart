import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/ledger_state.dart';
import '../theme/tokens.dart';

/// The persistent bottom navigation: four tabs flanking a raised green FAB that
/// opens the Add Transaction sheet.
class LedgerTabBar extends StatelessWidget {
  final AppTab active;
  final ValueChanged<AppTab> onTab;
  final VoidCallback onAdd;

  const LedgerTabBar({
    super.key,
    required this.active,
    required this.onTab,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 88,
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24),
          decoration: BoxDecoration(
            color: AppColors.screen.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tab(AppTab.home, Symbols.home_rounded, 'Home'),
              _tab(
                AppTab.accounts,
                Symbols.account_balance_wallet_rounded,
                'Accounts',
              ),
              _fab(),
              _tab(AppTab.activity, Symbols.receipt_long_rounded, 'Activity'),
              _tab(AppTab.insights, Symbols.insights_rounded, 'Insights'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(AppTab tab, IconData icon, String label) {
    final on = tab == active;
    final color = on ? AppColors.brand : AppColors.idleTab;
    return GestureDetector(
      key: ValueKey('tab_${label.toLowerCase()}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onTab(tab),
      child: SizedBox(
        width: 50,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 23, fill: on ? 1 : 0),
            const SizedBox(height: 4),
            Text(label, style: AppText.ui(10, FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _fab() {
    return GestureDetector(
      key: const ValueKey('addFab'),
      behavior: HitTestBehavior.opaque,
      onTap: onAdd,
      child: Transform.translate(
        offset: const Offset(0, -7),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
            boxShadow: AppShadows.fab,
          ),
          child: const Icon(
            Symbols.add_rounded,
            color: AppColors.onBrandDeep,
            size: 32,
          ),
        ),
      ),
    );
  }
}
