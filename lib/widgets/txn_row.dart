import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../view/txn_view.dart';
import 'icon_tile.dart';

/// One transaction line: avatar tile, payee + "category · account", signed
/// mono amount. Used on Home (Recent), Activity and Account Detail.
class TxnRow extends StatelessWidget {
  final TxnRowData data;
  final VoidCallback? onTap;
  final bool showDate; // show the transaction date under the amount
  const TxnRow(this.data, {super.key, this.onTap, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final row = Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconTile(
            size: 32,
            bg: data.iconBg,
            fg: data.iconFg,
            letter: data.letter,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.payee, style: AppText.ui(14, FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  data.sub,
                  style: AppText.muted12,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (showDate)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.amountText,
                  style: AppText.mono(
                    15,
                    FontWeight.w600,
                    color: data.amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.date,
                  style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
                ),
              ],
            )
          else
            Text(
              data.amountText,
              style: AppText.mono(15, FontWeight.w600, color: data.amountColor),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}
