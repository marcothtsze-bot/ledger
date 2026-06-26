import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../charts/donut_chart.dart';
import '../core/money.dart';
import '../core/statement.dart';
import '../models/account.dart';
import '../state/ledger_notifier.dart';
import '../theme/tokens.dart';
import '../view/txn_view.dart';
import '../widgets/enter_animations.dart';
import '../widgets/grouped_card.dart';
import '../widgets/section_header.dart';
import '../widgets/txn_row.dart';

/// Full-screen account detail: balance hero, credit utilisation (for cards),
/// and the transactions filtered to this account.
class AccountDetailOverlay extends ConsumerWidget {
  const AccountDetailOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);
    final a = s.accountById(s.overlayAcct);
    if (a == null) return const SizedBox.shrink();

    final txns = s.transactions.where((t) => t.acctId == a.id).toList();
    final limit = a.creditLimit ?? 0;
    final used = limit > 0 ? (a.balance.abs() / limit).clamp(0.0, 1.0) : 0.0;
    final today = DateTime.now();

    return EnterFade(
      child: Container(
        color: AppColors.screen,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 40),
          children: [
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: n.closeOverlay,
                  child: const Icon(
                    Symbols.chevron_left_rounded,
                    color: AppColors.brand,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a.name,
                    style: AppText.ui(18, FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => n.togglePin(a.id),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(
                      Symbols.star_rounded,
                      fill: a.pinned ? 1 : 0,
                      color: a.pinned ? AppColors.brand : AppColors.muted,
                      size: 22,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => n.openEditAccount(a.id),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.edit_rounded,
                        color: AppColors.brand,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Edit',
                        style: AppText.ui(
                          14,
                          FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: Column(
                children: [
                  Text(
                    a.sub.toUpperCase(),
                    style: AppText.ui(
                      12,
                      FontWeight.w400,
                      color: AppColors.muted,
                      spacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    signedMoney(a.balance, a.currency),
                    style: AppText.mono(40, FontWeight.w600, spacing: -0.8),
                  ),
                ],
              ),
            ),
            if (a.isLiability && limit > 0) ...[
              const SizedBox(height: 18),
              Center(
                child: DonutChart(
                  size: 120,
                  thickness: 14,
                  segments: [
                    DonutSegment(used, AppColors.amber),
                    DonutSegment(
                      1 - used,
                      Colors.white.withValues(alpha: 0.08),
                    ),
                  ],
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(used * 100).round()}%',
                        style: AppText.mono(
                          22,
                          FontWeight.w600,
                          color: AppColors.amber,
                        ),
                      ),
                      Text(
                        'utilised',
                        style: AppText.ui(
                          11,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '${money(limit - a.balance.abs(), a.currency)} of ${money(limit, a.currency)} available'
                  '${a.minPayment != null ? ' · min payment ${hk(a.minPayment!)}' : ''}',
                  style: AppText.ui(
                    12,
                    FontWeight.w400,
                    color: AppColors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (a.isCreditCard) ...[
              const SizedBox(height: 18),
              _statementCard(
                a,
                today,
                onEdit: () => n.openEditAccount(a.id),
                onPay: () => n.openPayStatement(a.id),
              ),
            ],
            const SizedBox(height: 22),
            const EyebrowLabel('Recent in this account'),
            const SizedBox(height: 10),
            if (txns.isEmpty)
              Text('No transactions yet.', style: AppText.muted12)
            else
              GroupedCard(
                children: [
                  for (final t in txns)
                    TxnRow(txnRowData(s, t), onTap: () => n.openEditTxn(t.id)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statementCard(
    Account a,
    DateTime today, {
    required VoidCallback onEdit,
    required VoidCallback onPay,
  }) {
    final configured =
        a.statementDay != null ||
        a.dueDay != null ||
        a.statementBalance != null;
    if (!configured) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onEdit,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set up the statement cycle',
                style: AppText.ui(15, FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                'Add the closing day, due day and statement balance so Ledger can show what to pay and when.',
                style: AppText.ui(
                  12.5,
                  FontWeight.w400,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tap to set up ›',
                style: AppText.ui(13, FontWeight.w600, color: AppColors.brand),
              ),
            ],
          ),
        ),
      );
    }
    final stmt = a.statementBalance ?? 0;
    final pending = pendingThisCycle(a.balance, a.statementBalance);
    if (stmt <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Symbols.check_circle_rounded,
                  color: AppColors.brand,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Statement cleared',
                  style: AppText.ui(15, FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.hairline),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next statement (so far)',
                  style: AppText.ui(
                    13,
                    FontWeight.w400,
                    color: AppColors.muted,
                  ),
                ),
                Text(hk(pending), style: AppText.mono(15, FontWeight.w600)),
              ],
            ),
            if (a.statementDay != null) ...[
              const SizedBox(height: 10),
              Text(
                'Next statement closes ${nextDueLabel(a.statementDay!, today)}',
                style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
              ),
            ],
          ],
        ),
      );
    }
    final dueLabel = a.dueDay != null ? nextDueLabel(a.dueDay!, today) : '—';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT STATEMENT · PAY FIRST',
                    style: AppText.eyebrow(
                      color: AppColors.expense,
                    ).copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    hk(a.statementBalance ?? 0),
                    style: AppText.mono(26, FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  'due $dueLabel',
                  style: AppText.ui(
                    12,
                    FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.hairline),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next statement (so far)',
                style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
              ),
              Text(hk(pending), style: AppText.mono(15, FontWeight.w600)),
            ],
          ),
          if (a.statementDay != null && a.dueDay != null) ...[
            const SizedBox(height: 10),
            Text(
              'Closes ${ordinalDay(a.statementDay!)} each month · pay by ${ordinalDay(a.dueDay!)}',
              style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPay,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                'Mark as paid',
                style: AppText.ui(
                  15,
                  FontWeight.w700,
                  color: AppColors.onBrand,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
