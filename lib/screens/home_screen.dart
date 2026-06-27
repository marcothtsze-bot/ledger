import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../charts/line_charts.dart';
import '../core/money.dart';
import '../core/statement.dart';
import '../models/account.dart';
import '../models/recurring.dart';
import '../state/ledger_notifier.dart';
import '../state/ledger_state.dart';
import '../theme/hex_color.dart';
import '../theme/icon_catalog.dart';
import '../theme/tokens.dart';
import '../view/account_type.dart';
import '../view/txn_view.dart';
import '../widgets/account_avatar.dart';
import '../widgets/grouped_card.dart';
import '../widgets/section_header.dart';
import '../widgets/txn_row.dart';

/// Net-worth dashboard: hero header, month stat cards, account preview,
/// upcoming charges and recent transactions.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);
    final pinned = s.pinnedAccounts;
    final net = s.incomeMonth - s.expenseMonth;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _header(context, s, n),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, kBottomNavInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statCard(
                    '▲ Income',
                    hk(s.incomeMonth),
                    AppColors.softGreen2,
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    '▼ Expense',
                    hk(s.expenseMonth),
                    AppColors.expenseMuted,
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'Net',
                    net >= 0 ? '+${hk(net)}' : signedHk(net),
                    AppColors.mutedNet,
                    valueColor: AppColors.brand,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SectionHeader(
                'Accounts',
                actionLabel: 'See all',
                onAction: () => n.goTab(AppTab.accounts),
              ),
              const SizedBox(height: 11),
              for (var i = 0; i < pinned.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                pinned[i].isCreditCard
                    ? _creditPreviewCard(
                        pinned[i],
                        () => n.openAccount(pinned[i].id),
                      )
                    : _simpleAccountCard(
                        pinned[i],
                        () => n.openAccount(pinned[i].id),
                      ),
              ],
              if (pinned.isEmpty)
                Text(
                  'Pin accounts to see them here — open an account and tap the ☆.',
                  style: AppText.muted12,
                ),
              const SizedBox(height: 22),
              SectionHeader(
                'Upcoming',
                actionLabel: 'Manage',
                onAction: n.openRecurring,
              ),
              const SizedBox(height: 11),
              _upcomingRow(s, n),
              const SizedBox(height: 22),
              SectionHeader(
                'Recent',
                actionLabel: 'See all',
                onAction: () => n.goTab(AppTab.activity),
              ),
              const SizedBox(height: 11),
              GroupedCard(
                children: [
                  for (final t in s.transactions.take(3))
                    TxnRow(txnRowData(s, t), onTap: () => n.openEditTxn(t.id)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, LedgerState s, LedgerNotifier n) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 50, 22, 26),
      decoration: const BoxDecoration(gradient: AppColors.homeHeaderGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Hi, Marco',
                  style: AppText.ui(19, FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      'June ▾',
                      style: AppText.ui(14, FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 9),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: n.openBackup,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.settings_rounded,
                        size: 19,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Net Worth · HKD',
            style: AppText.ui(
              11,
              FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
              spacing: 1.8,
            ),
          ),
          const SizedBox(height: 9),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: s.netWorth),
            duration: reduce ? Duration.zero : AppDurations.countUp,
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                signedHk(v),
                maxLines: 1,
                style: AppText.heroNetWorth,
              ),
            ),
          ),
          const SizedBox(height: 13),
          _trend(s),
        ],
      ),
    );
  }

  /// Real net-worth movement: the change since the end of last month plus a
  /// sparkline reconstructed from actual transactions (all converted to HKD).
  /// Before there's any prior-month history it says so honestly rather than
  /// showing a fabricated climb.
  Widget _trend(LedgerState s) {
    final now = DateTime.now();
    final change = s.netWorthChangeSinceLastMonth(now);
    final trend = s.netWorthTrend();

    final subtle = Colors.white.withValues(alpha: 0.8);
    if (change == null) {
      return Text(
        'Tracking from this month',
        style: AppText.ui(13, FontWeight.w400, color: subtle),
      );
    }

    final base = s.netWorth - change;
    final pct = base > 0 ? (change / base) * 100 : null;
    final up = change >= 0;
    final prevMonth = DateTime(
      now.year,
      now.month,
      1,
    ).subtract(const Duration(days: 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (pct != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: up ? AppColors.brand : AppColors.expense,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  '${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(1)}%',
                  style: AppText.mono(
                    13,
                    FontWeight.w700,
                    color: AppColors.onBrand,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                '${up ? '+' : '−'}${hk(change.abs())} '
                'since ${monthAbbrev(prevMonth.month)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(13, FontWeight.w400, color: subtle),
              ),
            ),
          ],
        ),
        if (trend.length >= 2) ...[
          const SizedBox(height: 16),
          Sparkline(values: trend, color: AppColors.softGreen),
        ],
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    Color labelColor, {
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
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
              style: AppText.ui(11, FontWeight.w600, color: labelColor),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppText.mono(
                  15,
                  FontWeight.w600,
                  color: valueColor ?? AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typePill(Account a) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        accountTypeLabel(a).toUpperCase(),
        style: AppText.ui(
          9.5,
          FontWeight.w700,
          color: AppColors.muted,
          spacing: 0.4,
        ),
      ),
    );
  }

  Widget _simpleAccountCard(Account a, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            AccountAvatar(account: a, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.name,
                          style: AppText.ui(14, FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 7),
                      _typePill(a),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(a.sub, style: AppText.muted12),
                ],
              ),
            ),
            Text(signedMoney(a.balance, a.currency), style: AppText.money),
          ],
        ),
      ),
    );
  }

  Widget _creditPreviewCard(Account a, VoidCallback onTap) {
    final used = a.creditLimit != null && a.creditLimit! > 0
        ? (a.balance.abs() / a.creditLimit!).clamp(0.0, 1.0)
        : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            AccountAvatar(account: a, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.name,
                          style: AppText.ui(14, FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 7),
                      _typePill(a),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: used,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.amber,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${(used * 100).round()}% used',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(
                            11,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              signedMoney(a.balance, a.currency),
              style: AppText.mono(
                15,
                FontWeight.w600,
                color: AppColors.expense,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Upcoming payments, soonest first (due/overdue float to the front), each
  /// card tappable to pay or settle.
  Widget _upcomingRow(LedgerState s, LedgerNotifier n) {
    final today = DateTime.now();
    final items = [...s.recurring]..sort((a, b) {
      final ad = a.nextDate, bd = b.nextDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    if (items.isEmpty) {
      return Text('No upcoming payments', style: AppText.muted12);
    }
    // Horizontal cards (design intent) so every upcoming item is reachable —
    // soonest/due first — not just the first three.
    return SizedBox(
      height: 134,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) =>
            SizedBox(width: 140, child: _upcomingCard(s, items[i], today, n)),
      ),
    );
  }

  Widget _upcomingCard(
    LedgerState s,
    Recurring r,
    DateTime today,
    LedgerNotifier n,
  ) {
    final t = DateTime(today.year, today.month, today.day);
    final isDue = r.nextDate != null && !r.nextDate!.isAfter(t);
    final cat = s.categoryById(r.catId);
    final tint = hexColor(r.color ?? cat.color);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => n.openSettleRecurring(r.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isDue ? AppColors.brand : AppColors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(iconFor(r.icon ?? cat.icon), size: 15, color: tint),
                ),
                const Spacer(),
                if (isDue)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Due',
                      style: AppText.ui(10, FontWeight.w700,
                          color: AppColors.brand),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              r.name,
              style: AppText.ui(14, FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              isDue ? 'Tap to pay' : 'next ${r.next}',
              style: AppText.muted12,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 9),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(hk(r.amount), maxLines: 1, style: AppText.money),
            ),
          ],
        ),
      ),
    );
  }
}
