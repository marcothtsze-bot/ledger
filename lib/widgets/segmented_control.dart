import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A pill segmented control (Expense/Income/Transfer, period selector). The
/// active segment fills brand-green; the rest are muted.
class SegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final Color background;
  final double fontSize;

  const SegmentedControl({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
    this.background = AppColors.card,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == activeIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[i],
                  style: AppText.ui(
                    fontSize,
                    FontWeight.w600,
                    color: active ? AppColors.onBrand : AppColors.muted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
