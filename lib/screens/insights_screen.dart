import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../charts/donut_chart.dart';
import '../charts/line_charts.dart';
import '../core/money.dart';
import '../state/ledger_notifier.dart';
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
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
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
        _cashFlowCard(),
        const SizedBox(height: 16),
        _spendingCard(),
        const SizedBox(height: 16),
        _recurringCard(
          s.recurring.length,
          hk(s.recurringMonthly),
          hk(s.recurringMonthly * 12),
          n.openRecurring,
        ),
        const SizedBox(height: 16),
        _trendCard(),
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

  Widget _cashFlowCard() {
    return _statCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cash flow', style: AppText.ui(15, FontWeight.w700)),
              Text(
                'net +16.2k',
                style: AppText.mono(
                  13,
                  FontWeight.w600,
                  color: AppColors.brand,
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
                _barGroup(0.55, 0.70, 'Apr', false),
                _barGroup(0.66, 0.58, 'May', false),
                _barGroup(0.90, 0.74, 'Jun', true),
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

  Widget _spendingCard() {
    return _statCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by category', style: AppText.ui(15, FontWeight.w700)),
          const SizedBox(height: 15),
          Row(
            children: [
              DonutChart(
                segments: const [
                  DonutSegment(34, Color(0xFFFF7A6B)),
                  DonutSegment(22, Color(0xFFF0A23A)),
                  DonutSegment(18, Color(0xFF5B8CFF)),
                  DonutSegment(14, Color(0xFFB69BFF)),
                  DonutSegment(12, Color(0xFF38BDF8)),
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
                    Text('18.7k', style: AppText.mono(15, FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _legendRow(const Color(0xFFFF7A6B), 'Dining', '6,380'),
                    _legendRow(const Color(0xFFF0A23A), 'Groceries', '4,120'),
                    _legendRow(const Color(0xFF5B8CFF), 'Transport', '3,350'),
                    _legendRow(const Color(0xFFB69BFF), 'Rent', '2,640'),
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

  Widget _trendCard() {
    return _statCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net worth trend', style: AppText.ui(15, FontWeight.w700)),
              Text(
                '▲ 14% / 12M',
                style: AppText.ui(12, FontWeight.w400, color: AppColors.brand),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const AreaChart(
            values: [50, 54, 52, 62, 60, 74, 80, 90, 88, 96, 102, 116],
            color: AppColors.brand,
          ),
        ],
      ),
    );
  }
}
