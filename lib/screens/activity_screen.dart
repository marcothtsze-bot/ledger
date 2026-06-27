import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/money.dart';
import '../core/statement.dart';
import '../state/ledger_notifier.dart';
import '../state/ledger_state.dart';
import '../theme/tokens.dart';
import '../view/txn_view.dart';
import '../widgets/grouped_card.dart';
import '../widgets/txn_row.dart';

/// Transaction history with live search and day-grouped lists.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(ledgerProvider).search);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);
    final flow = s.monthFlow(s.filterMonth);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, kBottomNavInset),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Activity', style: AppText.screenTitle),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.toggleFilter,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: s.hasActiveFilters
                      ? AppColors.brand.withValues(alpha: 0.16)
                      : AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: s.hasActiveFilters
                        ? AppColors.brand
                        : AppColors.hairlineStrong,
                  ),
                ),
                child: Icon(
                  Symbols.tune_rounded,
                  color: s.hasActiveFilters ? AppColors.brand : AppColors.muted,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.field),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              const Icon(
                Symbols.search_rounded,
                color: AppColors.muted,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: n.setSearch,
                  cursorColor: AppColors.brand,
                  style: AppText.ui(14, FontWeight.w400),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: InputBorder.none,
                    hintText: 'Search payee or category',
                    hintStyle: AppText.ui(
                      14,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (s.filterOpen) _filterPanel(s, n),
        // Month navigator + that month's in/out — hidden while searching, since
        // search spans every month.
        if (s.search.trim().isEmpty) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navArrow(Symbols.chevron_left_rounded, n.prevMonth),
              Text(
                '${monthAbbrev(s.filterMonth.month)} ${s.filterMonth.year}',
                style: AppText.ui(15, FontWeight.w700),
              ),
              _navArrow(Symbols.chevron_right_rounded, n.nextMonth),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summary('▲ In', hk(flow.income), AppColors.softGreen2),
              const SizedBox(width: 10),
              _summary('▼ Out', hk(flow.expense), AppColors.expenseMuted),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (s.activityGroups.isEmpty)
          _emptyState()
        else
          for (final g in s.activityGroups) ...[
            _groupHeader(g),
            const SizedBox(height: 9),
            GroupedCard(
              children: [
                for (final t in g.items)
                  TxnRow(txnRowData(s, t), onTap: () => n.openEditTxn(t.id)),
              ],
            ),
            const SizedBox(height: 18),
          ],
      ],
    );
  }

  Widget _filterPanel(LedgerState s, LedgerNotifier n) {
    Widget chip(String label, bool selected, VoidCallback onTap) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.brand.withValues(alpha: 0.16)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.brand : AppColors.hairline,
              ),
            ),
            child: Text(
              label,
              style: AppText.ui(12.5, FontWeight.w600,
                  color: selected ? AppColors.brand : AppColors.text),
            ),
          ),
        );

    Widget section(String title, List<Widget> chips) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.eyebrow().copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sheet,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('Type', [
            chip('All', s.filterType.isEmpty, () => n.setFilterType('')),
            chip('Expense', s.filterType == 'expense',
                () => n.setFilterType('expense')),
            chip('Income', s.filterType == 'income',
                () => n.setFilterType('income')),
            chip('Transfer', s.filterType == 'transfer',
                () => n.setFilterType('transfer')),
          ]),
          const SizedBox(height: 14),
          section('Account', [
            chip('All', s.filterAccountId.isEmpty,
                () => n.setFilterAccount('')),
            for (final a in s.accounts)
              chip(a.name, s.filterAccountId == a.id,
                  () => n.setFilterAccount(a.id)),
          ]),
          const SizedBox(height: 14),
          section('Category', [
            chip('All', s.filterCategoryId.isEmpty,
                () => n.setFilterCategory('')),
            for (final c in s.categories)
              chip(c.name, s.filterCategoryId == c.id,
                  () => n.setFilterCategory(c.id)),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: n.clearFilters,
                child: Text('Clear all',
                    style: AppText.ui(13, FontWeight.w600,
                        color: AppColors.expense)),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: n.toggleFilter,
                child: Text('Done',
                    style: AppText.ui(13, FontWeight.w700,
                        color: AppColors.brand)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Icon(icon, size: 20, color: AppColors.muted),
    ),
  );

  Widget _summary(String label, String value, Color labelColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
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
            const SizedBox(height: 3),
            Text(value, style: AppText.mono(16, FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _groupHeader(ActivityGroup g) {
    final positive = g.total >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            dayLabel(g.date, DateTime.now()).toUpperCase(),
            style: AppText.ui(
              13,
              FontWeight.w700,
              color: AppColors.muted,
              spacing: 0.5,
            ),
          ),
          Text(
            '${positive ? '+' : '−'}${fmtAmount(g.total)}',
            style: AppText.mono(
              12,
              FontWeight.w400,
              color: positive ? AppColors.brand : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      child: Column(
        children: [
          const Icon(
            Symbols.search_off_rounded,
            color: AppColors.muted,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'No matches',
            style: AppText.ui(15, FontWeight.w600, color: AppColors.mutedLight),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search or filter.',
            style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
