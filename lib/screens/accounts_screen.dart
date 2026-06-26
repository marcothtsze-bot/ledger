import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/money.dart';
import '../core/statement.dart';
import '../models/account.dart';
import '../state/ledger_notifier.dart';
import '../state/ledger_state.dart';
import '../theme/tokens.dart';
import '../widgets/account_avatar.dart';
import '../widgets/account_list_tile.dart';
import '../widgets/grouped_card.dart';
import '../widgets/section_header.dart';

/// Accounts overview: net-worth split, then grouped cash, credit and
/// investment lists. Rows open the Account Detail overlay.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);

    List<Account> inGroup(String g) =>
        s.accounts.where((a) => (a.group ?? 'cashbank') == g).toList();
    final cashBank = inGroup('cashbank');
    final invest = inGroup('invest');
    final credit = inGroup('credit');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, kBottomNavInset),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Accounts', style: AppText.screenTitle),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.openAcctSheet,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.hairlineStrong),
                ),
                child: const Icon(
                  Symbols.add_rounded,
                  color: AppColors.brand,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _netWorthCard(s),
        const SizedBox(height: 24),
        const EyebrowLabel('Cash & Bank'),
        const SizedBox(height: 10),
        GroupedCard(
          children: [
            for (final a in cashBank)
              AccountListTile(account: a, onTap: () => n.openAccount(a.id)),
          ],
        ),
        if (credit.isNotEmpty) ...[
          const SizedBox(height: 22),
          const EyebrowLabel('Credit cards'),
          const SizedBox(height: 10),
          for (var i = 0; i < credit.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _creditCard(credit[i], () => n.openAccount(credit[i].id)),
          ],
        ],
        const SizedBox(height: 22),
        const EyebrowLabel('Investments & assets'),
        const SizedBox(height: 10),
        GroupedCard(
          children: [
            for (final a in invest)
              AccountListTile(
                account: a,
                onTap: () => n.openAccount(a.id),
                noteColor: AppColors.brand,
              ),
          ],
        ),
      ],
    );
  }

  Widget _netWorthCard(LedgerState s) {
    final assets = s.assets;
    final liab = s.liabilities;
    final total = max(assets + liab, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.statCard),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Net worth',
                style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    signedHk(s.netWorth),
                    maxLines: 1,
                    style: AppText.mono(20, FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 12,
            child: Row(
              children: [
                Expanded(
                  flex: max((assets / total * 1000).round(), 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                if (liab > 0) ...[
                  const SizedBox(width: 3),
                  Expanded(
                    flex: max((liab / total * 1000).round(), 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.expense,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _legend(
                AppColors.brand,
                'Assets',
                fmtAmount(assets),
                AppColors.text,
              ),
              _legend(
                AppColors.expense,
                'Liabilities',
                fmtAmount(liab),
                AppColors.expense,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color dot, String label, String value, Color valueColor) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: dot,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: AppText.mono(13, FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }

  Widget _creditCard(Account a, VoidCallback onTap) {
    final limit = a.creditLimit ?? 0;
    final used = limit > 0 ? (a.balance.abs() / limit).clamp(0.0, 1.0) : 0.0;
    final available = limit - a.balance.abs();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          children: [
            Row(
              children: [
                AccountAvatar(account: a),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(a.name, style: AppText.ui(15, FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        a.statementDay != null && a.dueDay != null
                            ? 'Closes ${ordinalDay(a.statementDay!)} · due ${nextDueLabel(a.dueDay!, DateTime.now())}'
                            : a.sub,
                        style: AppText.muted12,
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
            if (limit > 0) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(used * 100).round()}% of ${hk(limit)} limit',
                    style: AppText.ui(
                      11,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    '${hk(available)} available',
                    style: AppText.ui(
                      11,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
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
                    widthFactor: used,
                    child: Container(color: AppColors.amber),
                  ),
                ),
              ),
            ],
            if (a.statementBalance != null) ...[
              const SizedBox(height: 13),
              Container(height: 1, color: AppColors.hairline),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current statement',
                          style: AppText.ui(
                            11,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hk(a.statementBalance ?? 0),
                          style: AppText.mono(
                            15,
                            FontWeight.w600,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Next statement',
                          style: AppText.ui(
                            11,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          money(pendingThisCycle(a.balance, a.statementBalance), a.currency),
                          style: AppText.mono(15, FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
