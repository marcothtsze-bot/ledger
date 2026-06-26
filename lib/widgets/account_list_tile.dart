import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/account.dart';
import '../theme/tokens.dart';
import 'account_avatar.dart';

/// A standard account row: monogram tile, name + sub, right-aligned balance and
/// optional note. Used in the Accounts screen's grouped lists.
class AccountListTile extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;
  final Color noteColor;

  const AccountListTile({
    super.key,
    required this.account,
    this.onTap,
    this.noteColor = AppColors.muted,
  });

  @override
  Widget build(BuildContext context) {
    final a = account;
    final content = Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          AccountAvatar(account: a),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.name, style: AppText.ui(15, FontWeight.w600)),
                if (a.sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(a.sub, style: AppText.muted12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                signedHk(a.balance),
                style: AppText.mono(
                  15,
                  FontWeight.w600,
                  color: a.isLiability ? AppColors.expense : AppColors.text,
                ),
              ),
              if (a.note != null && a.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    a.note!,
                    style: AppText.ui(11, FontWeight.w400, color: noteColor),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}
