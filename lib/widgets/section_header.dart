import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A section title with an optional trailing action link (e.g. "See all").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppText.sectionHeader),
          if (actionLabel != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: AppText.ui(13, FontWeight.w600, color: AppColors.brand),
              ),
            ),
        ],
      ),
    );
  }
}

/// An uppercase, letter-spaced eyebrow label (e.g. "CASH & BANK").
class EyebrowLabel extends StatelessWidget {
  final String text;
  const EyebrowLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text.toUpperCase(),
        style: AppText.eyebrow().copyWith(fontSize: 12),
      ),
    );
  }
}
