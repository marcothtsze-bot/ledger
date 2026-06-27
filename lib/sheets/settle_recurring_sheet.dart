import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/money.dart';
import '../core/statement.dart';
import '../state/ledger_notifier.dart';
import '../theme/hex_color.dart';
import '../theme/icon_catalog.dart';
import '../theme/tokens.dart';
import '../widgets/account_avatar.dart';
import '../widgets/enter_animations.dart';
import '../widgets/icon_tile.dart';
import 'sheet_chrome.dart';

/// Bottom sheet for an upcoming payment: pay it from a chosen account (records a
/// transaction) or mark it settled (advance the date only). Mounted while
/// `payRecurringId` is set.
class SettleRecurringSheet extends ConsumerWidget {
  const SettleRecurringSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ledgerProvider);
    final n = ref.read(ledgerProvider.notifier);

    final matches = s.recurring.where((x) => x.id == s.payRecurringId);
    if (matches.isEmpty) return const SizedBox.shrink();
    final r = matches.first;
    final cat = s.categoryById(r.catId);
    final tint = hexColor(r.color ?? cat.color);
    final due = r.nextDate != null ? compactDate(r.nextDate!) : r.next;
    final acct = s.accountById(r.accountId ?? '');
    // A recurring billed to a credit card charges that card's statement
    // directly — no separate pay-from account.
    final isCardBilled = acct?.isCreditCard ?? false;

    return Stack(
      children: [
        Positioned.fill(
          child: EnterFade(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.closeSettleRecurring,
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: EnterSlideUp(
            child: SheetPanel(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.86,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SheetHandle(),
                    SheetHeader(
                      title: isCardBilled ? 'Charge ${r.name}' : 'Pay ${r.name}',
                      onCancel: n.closeSettleRecurring,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _summary(r.name, r.icon, cat.icon, tint,
                                money(r.amount, acct?.currency ?? 'HKD'),
                                'Due $due'),
                            const SizedBox(height: 18),
                            if (isCardBilled) ...[
                              Text(
                                'Billed straight to your ${acct!.name} '
                                'statement — no separate payment needed.',
                                style: AppText.ui(13, FontWeight.w400,
                                    color: AppColors.muted, height: 1.4),
                              ),
                              const SizedBox(height: 14),
                              _actionButton(
                                label: 'Charge to ${acct.name}',
                                filled: true,
                                onTap: () => n.chargeToCard(r.id),
                              ),
                              const SizedBox(height: 9),
                              _actionButton(
                                label: 'Mark settled (no charge)',
                                filled: false,
                                onTap: () => n.settleRecurring(r.id),
                              ),
                            ] else ...[
                              Text(
                                'PAY FROM',
                                style: AppText.eyebrow().copyWith(fontSize: 11),
                              ),
                              const SizedBox(height: 10),
                              for (final a in s.accounts) ...[
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => n.payRecurring(r.id, a.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.card,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.card),
                                      border:
                                          Border.all(color: AppColors.hairline),
                                    ),
                                    child: Row(
                                      children: [
                                        AccountAvatar(account: a),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            a.name,
                                            style:
                                                AppText.ui(15, FontWeight.w600),
                                          ),
                                        ),
                                        Text(
                                          signedMoney(a.balance, a.currency),
                                          style: AppText.mono(
                                              13, FontWeight.w600,
                                              color: AppColors.muted),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                            Symbols.chevron_right_rounded,
                                            size: 18, color: AppColors.muted),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 9),
                              ],
                              const SizedBox(height: 6),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => n.settleRecurring(r.id),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: AppColors.hairlineStrong),
                                  ),
                                  child: Text(
                                    'Mark settled (no transaction)',
                                    style: AppText.ui(14, FontWeight.w600,
                                        color: AppColors.mutedLight),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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

  Widget _actionButton({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.brand : null,
          borderRadius: BorderRadius.circular(15),
          border: filled ? null : Border.all(color: AppColors.hairlineStrong),
        ),
        child: Text(
          label,
          style: AppText.ui(14, FontWeight.w600,
              color: filled ? AppColors.onBrand : AppColors.mutedLight),
        ),
      ),
    );
  }

  Widget _summary(String name, String? icon, String catIcon, Color tint,
      String amount, String sub) {
    return Row(
      children: [
        IconTile(
          size: 44,
          radius: 13,
          bg: tint.withValues(alpha: 0.16),
          fg: tint,
          glyphSize: 22,
          icon: iconFor(icon ?? catIcon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: AppText.ui(16, FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub, style: AppText.muted12),
            ],
          ),
        ),
        Text(amount, style: AppText.mono(18, FontWeight.w700)),
      ],
    );
  }
}
