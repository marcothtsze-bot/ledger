import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/money.dart';
import '../models/recurring.dart';
import '../state/ledger_notifier.dart';
import '../state/ledger_state.dart';
import '../theme/hex_color.dart';
import '../theme/icon_catalog.dart';
import '../theme/tokens.dart';
import '../widgets/enter_animations.dart';
import '../widgets/icon_tile.dart';
import '../widgets/section_header.dart';

/// Full-screen recurring view: monthly/annual commitment, subscriptions list,
/// and installment plans with progress.
class RecurringOverlay extends ConsumerWidget {
  const RecurringOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);
    final subs = s.subscriptions;
    final installments = s.installments;

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
                Text(
                  'Recurring',
                  style: AppText.ui(24, FontWeight.w800, spacing: -0.5),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _statCard('Monthly commitment', hk(s.recurringMonthly)),
                const SizedBox(width: 10),
                _statCard('Annualised', hk(s.recurringMonthly * 12)),
              ],
            ),
            if (s.duplicateRecurringCount > 0) ...[
              const SizedBox(height: 16),
              _duplicateBanner(s, n),
            ],
            const SizedBox(height: 24),
            const EyebrowLabel('Subscriptions'),
            const SizedBox(height: 10),
            for (final r in subs) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => n.openEditRecurring(r.id),
                child: _subRow(s, r),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            const EyebrowLabel('Installment plans'),
            const SizedBox(height: 10),
            if (installments.isEmpty)
              _installmentEmpty()
            else
              for (final r in installments) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => n.openEditRecurring(r.id),
                  child: _installmentRow(s, r),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _duplicateBanner(LedgerState s, LedgerNotifier n) {
    final count = s.duplicateRecurringCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.merge_rounded, color: AppColors.amber, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count possible duplicate${count == 1 ? '' : 's'}',
                  style: AppText.ui(13.5, FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text('Same name, amount & account.', style: AppText.muted12),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: n.mergeDuplicateRecurring,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Merge',
                style: AppText.ui(13, FontWeight.w700, color: AppColors.screen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppText.mono(20, FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subRow(LedgerState s, Recurring r) {
    final c = s.categoryById(r.catId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          IconTile(
            size: 34,
            bg: hexColor('${r.color ?? c.color}29'),
            fg: hexColor(r.color ?? c.color),
            glyphSize: 17,
            icon: r.icon != null ? iconFor(r.icon!) : null,
            letter: r.icon == null ? r.name.substring(0, 1).toUpperCase() : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.name, style: AppText.ui(15, FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${r.freq} · next ${r.next}', style: AppText.muted12),
              ],
            ),
          ),
          Text(hk(r.amount), style: AppText.money),
          const SizedBox(width: 6),
          const Icon(Symbols.chevron_right_rounded, size: 18, color: AppColors.idleTab),
        ],
      ),
    );
  }

  Widget _installmentRow(LedgerState s, Recurring r) {
    final c = s.categoryById(r.catId);
    final total = r.total ?? 1;
    final paid = r.paid ?? 0;
    final remaining = (total - paid) * r.amount;
    final pct = (paid / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(
                size: 34,
                bg: hexColor('${c.color}29'),
                fg: hexColor(c.color),
                letter: r.name.substring(0, 1).toUpperCase(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(r.name, style: AppText.ui(15, FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${hk(r.amount)}/mo · next ${r.next}',
                      style: AppText.muted12,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hk(remaining),
                    style: AppText.mono(
                      14,
                      FontWeight.w600,
                      color: AppColors.amber,
                    ),
                  ),
                  Text(
                    'left to pay',
                    style: AppText.ui(
                      11,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Symbols.chevron_right_rounded,
                size: 18,
                color: AppColors.idleTab,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$paid of $total months',
                style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
              ),
              Text(
                '${hk(paid * r.amount)} paid',
                style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 7,
              color: Colors.white.withValues(alpha: 0.08),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(color: AppColors.brand),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _installmentEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Text(
            'No installment plans yet',
            style: AppText.ui(14, FontWeight.w600, color: AppColors.mutedLight),
          ),
          const SizedBox(height: 5),
          Text(
            'Paying off a big purchase over time? Add a transaction, turn on Repeat → Installments, and it will track here.',
            textAlign: TextAlign.center,
            style: AppText.ui(
              12.5,
              FontWeight.w400,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
