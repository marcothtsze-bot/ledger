import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../charts/donut_chart.dart';
import '../charts/line_charts.dart';
import '../core/money.dart';
import '../core/statement.dart';
import '../state/ledger_notifier.dart';
import '../state/ledger_state.dart';
import '../theme/hex_color.dart';
import '../theme/icon_catalog.dart';
import '../theme/tokens.dart';
import '../widgets/segmented_control.dart';

/// Analytics: cash flow, spending breakdown, recurring summary and net-worth
/// trend. Chart sample data follows the design prototype; the recurring figures
/// are live from state.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _period = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, kBottomNavInset),
      children: [
        Text('Insights', style: AppText.screenTitle),
        const SizedBox(height: 16),
        SegmentedControl(
          labels: const ['3M', 'MTD', '12M', 'YTD'],
          activeIndex: _period,
          fontSize: 13,
          onChanged: (i) => setState(() => _period = i),
        ),
        const SizedBox(height: 20),
        _cashFlowCard(s),
        const SizedBox(height: 16),
        _spendingCard(s),
        const SizedBox(height: 16),
        _budgetsCard(s, n),
        const SizedBox(height: 16),
        _recurringCard(
          s.recurring.length,
          hk(s.recurringMonthly),
          hk(s.recurringMonthly * 12),
          n.openRecurring,
        ),
        const SizedBox(height: 16),
        _trendCard(s),
      ],
    );
  }

  Widget _statCardShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.statCard),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
  }

  Widget _budgetsCard(LedgerState s, LedgerNotifier n) {
    final spend = s.categorySpendThisMonth(DateTime.now());
    final entries = s.budgets.entries.toList()
      ..sort((a, b) => (spend[b.key] ?? 0).compareTo(spend[a.key] ?? 0));
    return _statCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Budgets', style: AppText.ui(15, FontWeight.w700)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: n.openNewCategory,
                child: Text(
                  '+ Set a budget',
                  style: AppText.ui(12.5, FontWeight.w700,
                      color: AppColors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text('This month · tap a row to adjust', style: AppText.muted12),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              'No budgets yet. Tap "+ Set a budget" to create a category with a '
              'monthly limit, or edit an existing category to add one.',
              style: AppText.ui(13, FontWeight.w400,
                  color: AppColors.muted, height: 1.45),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => n.openEditCategory(entries[i].key),
                child: _budgetRow(
                  s,
                  entries[i].key,
                  entries[i].value,
                  spend[entries[i].key] ?? 0,
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _budgetRow(LedgerState s, String catId, double limit, double spent) {
    final c = s.categoryById(catId);
    final tint = hexColor(c.color);
    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final over = spent > limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(iconFor(c.icon), size: 16, color: tint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.name, style: AppText.ui(14, FontWeight.w600)),
            ),
            Text(
              '${hk(spent)} / ${hk(limit)}',
              style: AppText.mono(12, FontWeight.w600,
                  color: over ? AppColors.expense : AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 7,
            color: Colors.white.withValues(alpha: 0.08),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(color: over ? AppColors.expense : tint),
            ),
          ),
        ),
      ],
    );
  }

  /// Number of monthly bars the cash-flow chart shows for the active period.
  int _flowMonths(DateTime now) => switch (_period) {
    0 => 3, // 3M
    1 => 1, // MTD
    2 => 12, // 12M
    _ => now.month, // YTD (Jan..now)
  };

  /// Inclusive start date for the spending breakdown of the active period.
  DateTime _spendStart(DateTime now) => switch (_period) {
    0 => DateTime(now.year, now.month - 2, 1), // 3M
    1 => DateTime(now.year, now.month, 1), // MTD
    2 => DateTime(now.year, now.month - 11, 1), // 12M
    _ => DateTime(now.year, 1, 1), // YTD
  };

  /// Compact money label, e.g. 16234 -> '16.2k'.
  String _compact(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.round().toString();

  Widget _cashFlowCard(LedgerState s) {
    final now = DateTime.now();
    final flows = s.monthlyFlow(now, _flowMonths(now));
    final net = flows.fold<double>(0, (sum, f) => sum + f.net);
    final peak = flows.fold<double>(
      1,
      (m, f) => max(m, max(f.income, f.expense)),
    );
    final up = net >= 0;
    return _statCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cash flow', style: AppText.ui(15, FontWeight.w700)),
              Text(
                'net ${up ? '+' : '−'}${_compact(net.abs())}',
                style: AppText.mono(
                  13,
                  FontWeight.w600,
                  color: up ? AppColors.brand : AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final f in flows)
                  _barGroup(
                    f.income / peak,
                    f.expense / peak,
                    monthAbbrev(f.month.month),
                    f.month.year == now.year && f.month.month == now.month,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barGroup(
    double income,
    double expense,
    String label,
    bool highlight,
  ) {
    Widget bar(double frac, Color color) => Container(
      width: 9,
      height: 78 * frac,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              bar(income, AppColors.brand),
              const SizedBox(width: 3),
              bar(expense, const Color(0xFF33403A)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppText.ui(
              11,
              highlight ? FontWeight.w700 : FontWeight.w400,
              color: highlight ? AppColors.text : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _spendingCard(LedgerState s) {
    final now = DateTime.now();
    final spend = s.categorySpendInRange(_spendStart(now), now);
    final ranked = spend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = ranked.fold<double>(0, (sum, e) => sum + e.value);
    const topN = 5;
    final top = ranked.take(topN).toList();
    final other = ranked.skip(topN).fold<double>(0, (sum, e) => sum + e.value);

    return _statCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by category', style: AppText.ui(15, FontWeight.w700)),
          const SizedBox(height: 15),
          if (total <= 0)
            Text(
              'No spending in this period.',
              style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
            )
          else
            Row(
              children: [
                DonutChart(
                  segments: [
                    for (final e in top)
                      DonutSegment(
                        e.value,
                        hexColor(s.categoryById(e.key).color),
                      ),
                    if (other > 0) DonutSegment(other, AppColors.muted),
                  ],
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SPENT',
                        style: AppText.ui(
                          10,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        _compact(total),
                        style: AppText.mono(15, FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (final e in top)
                        _legendRow(
                          hexColor(s.categoryById(e.key).color),
                          s.categoryById(e.key).name,
                          fmtAmount(e.value),
                        ),
                      if (other > 0)
                        _legendRow(AppColors.muted, 'Other', fmtAmount(other)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _legendRow(Color dot, String name, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: AppText.ui(13, FontWeight.w400))),
          Text(
            value,
            style: AppText.mono(
              13,
              FontWeight.w400,
              color: AppColors.mutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recurringCard(
    int count,
    String monthly,
    String annual,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _statCardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Recurring & subscriptions',
                  style: AppText.ui(15, FontWeight.w700),
                ),
                Text(
                  '$count active ›',
                  style: AppText.ui(
                    13,
                    FontWeight.w400,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(monthly, style: AppText.mono(24, FontWeight.w600)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '/mo',
                    style: AppText.ui(
                      13,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$annual per year · tap to manage',
              style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(LedgerState s) {
    final now = DateTime.now();
    final change = s.netWorthChangeSinceLastMonth(now);
    final trend = s.netWorthTrend(points: 12);
    final up = (change ?? 0) >= 0;
    double? pct;
    if (change != null) {
      final prev = s.netWorth - change;
      if (prev > 0) pct = (change / prev) * 100;
    }
    return _statCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net worth trend', style: AppText.ui(15, FontWeight.w700)),
              if (pct != null)
                Text(
                  '${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(1)}% / mo',
                  style: AppText.ui(
                    12,
                    FontWeight.w400,
                    color: up ? AppColors.brand : AppColors.expense,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (trend.length >= 2)
            AreaChart(values: trend, color: AppColors.brand)
          else
            Text(
              'Your net-worth trend will appear here as you add transactions.',
              style: AppText.ui(
                13,
                FontWeight.w400,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }
}
