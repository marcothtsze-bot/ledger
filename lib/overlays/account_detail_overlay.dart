import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../charts/donut_chart.dart';
import '../core/money.dart';
import '../core/statement.dart';
import '../models/account.dart';
import '../models/enums.dart';
import '../state/ledger_notifier.dart';
import '../state/ledger_state.dart';
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

    final txns = s.transactions.where((t) => t.acctId == a.id).toList()
      ..sort((x, y) => y.date.compareTo(x.date)); // newest first, for reconciling
    final limit = a.creditLimit ?? 0;
    // Reserve committed-but-unbilled installments against the limit too.
    final reserved = s.cardReserved(a.id);
    final committed = s.installmentCommitmentRemaining(a.id);
    final used = limit > 0 ? (reserved / limit).clamp(0.0, 1.0) : 0.0;
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
                  '${money(limit - reserved, a.currency)} of ${money(limit, a.currency)} available'
                  '${committed > 0 ? ' · reserves ${money(committed, a.currency)} committed installments' : ''}'
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
              _committedSection(s, a, today),
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
                    TxnRow(
                      txnRowData(s, t),
                      onTap: () => n.openEditTxn(t.id),
                      showDate: true,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Forward look at what recurring charges (subscriptions + installments) are
  /// already committed to this card's next statement, so the user can see the
  /// load before buying more. Hidden when nothing is committed.
  /// The next statement's close date and payment-due date for card [a] as of
  /// [today]. A charge made now lands on this statement (anything after the most
  /// recent close rolls to the next one), so its due date is one cycle out.
  (DateTime?, DateTime?) _nextStatementDates(Account a, DateTime today) {
    final close = a.statementDay != null
        ? nextOccurrence(a.statementDay!, today)
        : null;
    final due = (close != null && a.dueDay != null)
        ? nextOccurrence(a.dueDay!, close)
        : null;
    return (close, due);
  }

  /// One-line "new charges land on the statement closing X, due Y" for a card —
  /// makes clear that a charge made after the close is due a cycle later.
  String _nextStatementLine(Account a, DateTime today) {
    final (close, due) = _nextStatementDates(a, today);
    if (close == null) return 'New charges bill your next statement';
    final dueTxt = due != null ? ' · due ${_dayLabel(due)}' : '';
    return 'New charges bill the statement closing ${_dayLabel(close)}$dueTxt';
  }

  Widget _committedSection(LedgerState s, Account a, DateTime today) {
    final statements = s.upcomingStatements(a.id, today);
    if (statements.isEmpty) return const SizedBox.shrink();
    return _UpcomingOnCard(statements: statements, currency: a.currency);
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
      // A null statement balance means no statement has closed yet — the whole
      // balance is still accumulating. Don't claim "cleared" when money is owed.
      final neverClosed = a.statementBalance == null && a.balance.abs() > 0.005;
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
                Icon(
                  neverClosed
                      ? Symbols.receipt_long_rounded
                      : Symbols.check_circle_rounded,
                  color: neverClosed ? AppColors.muted : AppColors.brand,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  neverClosed ? 'No statement closed yet' : 'Statement cleared',
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
                  neverClosed ? 'Balance so far' : 'Next statement (so far)',
                  style: AppText.ui(
                    13,
                    FontWeight.w400,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  money(pending, a.currency),
                  style: AppText.mono(15, FontWeight.w600),
                ),
              ],
            ),
            if (a.statementDay != null) ...[
              const SizedBox(height: 10),
              Text(
                _nextStatementLine(a, today),
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
                    money(a.statementBalance ?? 0, a.currency),
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
          if (a.statementDay != null) ...[
            const SizedBox(height: 10),
            Text(
              _nextStatementLine(a, today),
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

String _dayLabel(DateTime d) => '${monthAbbrev(d.month)} ${d.day}';

/// The "Upcoming on this card" box — a collapsible forward look at the
/// installments + subscriptions already committed to future statements. Starts
/// collapsed (just the total) so the transactions below stay reachable.
class _UpcomingOnCard extends StatefulWidget {
  final List<UpcomingStatement> statements;
  final String currency;
  const _UpcomingOnCard({required this.statements, required this.currency});

  @override
  State<_UpcomingOnCard> createState() => _UpcomingOnCardState();
}

class _UpcomingOnCardState extends State<_UpcomingOnCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final statements = widget.statements;
    final currency = widget.currency;
    final grandTotal = statements.fold<double>(0, (sum, st) => sum + st.total);
    final count = statements.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'UPCOMING ON THIS CARD',
                          style: AppText.eyebrow().copyWith(fontSize: 11),
                        ),
                      ),
                      Text(
                        money(grandTotal, currency),
                        style: AppText.mono(
                          15,
                          FontWeight.w700,
                          color: AppColors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded
                            ? Symbols.expand_less_rounded
                            : Symbols.expand_more_rounded,
                        color: AppColors.muted,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _expanded
                        ? 'Installments & subscriptions booked ahead, grouped by '
                              'the statement they land on.'
                        : '$count upcoming statement${count == 1 ? '' : 's'} · tap to view',
                    style: AppText.ui(
                      12,
                      FontWeight.w400,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (_expanded)
              for (final st in statements) _statementBlock(st, currency),
          ],
        ),
      ),
    );
  }

  Widget _statementBlock(UpcomingStatement st, String currency) {
    final header = [
      'Closes ${_dayLabel(st.close)}',
      if (st.due != null) 'due ${_dayLabel(st.due!)}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                header,
                style: AppText.ui(12.5, FontWeight.w700, color: AppColors.brand),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              money(st.total, currency),
              style: AppText.mono(14, FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < st.charges.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          _chargeRow(st.charges[i], currency),
        ],
      ],
    );
  }

  Widget _chargeRow(StatementCharge ch, String currency) {
    final r = ch.source;
    final isInstallment = r.kind == RecurringKind.installment;
    final tag = isInstallment
        ? (ch.count > 1 ? 'Installment ×${ch.count}' : 'Installment')
        : (ch.count > 1 ? 'Subscription ×${ch.count}' : 'Subscription');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.name, style: AppText.ui(14, FontWeight.w600)),
              const SizedBox(height: 1),
              Text(tag, style: AppText.muted12),
            ],
          ),
        ),
        Text(money(ch.amount, currency), style: AppText.mono(14, FontWeight.w600)),
      ],
    );
  }
}
