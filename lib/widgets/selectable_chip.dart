import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A pill chip with a selected (brand-filled) and unselected state — used for
/// the account Type and Currency choices in the Add Account sheet.
class SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double radius;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.radius = AppRadii.pill,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.hairlineStrong,
          ),
        ),
        child: Text(
          label,
          style: AppText.ui(
            13,
            FontWeight.w600,
            color: selected ? AppColors.onBrand : AppColors.mutedLight,
          ),
        ),
      ),
    );
  }
}
