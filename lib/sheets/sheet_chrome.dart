import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The bottom-sheet panel surface: sheet-coloured, top corners rounded, hairline
/// top edge. Pass a fixed [height] for full sheets, or leave null to wrap.
class SheetPanel extends StatelessWidget {
  final Widget child;
  final double? height;
  const SheetPanel({super.key, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.sheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
        border: Border(top: BorderSide(color: AppColors.hairlineStrong)),
      ),
      child: child,
    );
  }
}

/// The little grab handle at the top of a sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 38,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// Cancel · centered title · spacer row used at the top of sheets.
class SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onCancel;
  final String cancelLabel;
  final double bottomPadding;

  const SheetHeader({
    super.key,
    required this.title,
    required this.onCancel,
    this.cancelLabel = 'Cancel',
    this.bottomPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 6, 20, bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCancel,
            child: Text(
              cancelLabel,
              style: AppText.ui(15, FontWeight.w400, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(16, FontWeight.w700),
            ),
          ),
          const SizedBox(width: 46),
        ],
      ),
    );
  }
}
