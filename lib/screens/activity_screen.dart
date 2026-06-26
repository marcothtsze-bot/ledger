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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Activity', style: AppText.screenTitle),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairlineStrong),
              ),
              child: const Icon(
                Symbols.tune_rounded,
                color: AppColors.muted,
                size: 18,
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
        const SizedBox(height: 16),
        Row(
          children: [
            _summary('▲ In · June', hk(s.incomeMonth), AppColors.softGreen2),
            const SizedBox(width: 10),
            _summary(
              '▼ Out · June',
              hk(s.expenseMonth),
              AppColors.expenseMuted,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (s.noSearchResults)
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
            'Try a different search term.',
            style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
