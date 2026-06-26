import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The brand-green pill action button (Save, Add account, …) with its glow.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 15),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(15),
          boxShadow: AppShadows.primaryButton,
        ),
        child: Text(
          label,
          style: AppText.ui(16, FontWeight.w700, color: AppColors.onBrand),
        ),
      ),
    );
  }
}
