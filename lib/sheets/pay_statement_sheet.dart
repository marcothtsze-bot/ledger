import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/money.dart';
import '../state/ledger_notifier.dart';
import '../theme/tokens.dart';
import '../widgets/account_avatar.dart';
import '../widgets/enter_animations.dart';
import 'sheet_chrome.dart';

/// Bottom sheet to pay a credit card's statement: choose which cash/bank account
/// the money comes from. Mounted by the shell while [payCardId] is set.
class PayStatementSheet extends ConsumerWidget {
  const PayStatementSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);
    final card = s.accountById(s.payCardId);
    if (card == null) return const SizedBox.shrink();
    final amount = card.statementBalance ?? 0;
    final accounts = s.payableAccounts;

    return Stack(
      children: [
        Positioned.fill(
          child: EnterFade(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.closePayStatement,
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: EnterSlideUp(
            child: SheetPanel(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SheetHandle(),
                    SheetHeader(
                      title: 'Pay statement',
                      onCancel: n.closePayStatement,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(
                                AppRadii.card,
                              ),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STATEMENT DUE',
                                  style: AppText.eyebrow(
                                    color: AppColors.expense,
                                  ).copyWith(fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      money(amount, card.currency),
                                      style: AppText.mono(28, FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          'to ${card.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.ui(
                                            13,
                                            FontWeight.w400,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Pay from',
                            style: AppText.ui(
                              12,
                              FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (accounts.isEmpty)
                            Text(
                              'No cash or bank account to pay from — add one first.',
                              style: AppText.muted12,
                            )
                          else
                            for (final a in accounts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => n.payStatement(a.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.card,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.card,
                                      ),
                                      border: Border.all(
                                        color: AppColors.hairline,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        AccountAvatar(account: a),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                a.name,
                                                style: AppText.ui(
                                                  15,
                                                  FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Balance ${signedMoney(a.balance, a.currency)}',
                                                style: AppText.muted12,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Symbols.arrow_forward_rounded,
                                          color: AppColors.brand,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
