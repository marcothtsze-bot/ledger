import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The brand-green success pill shown after a save. Rises and fades in; the
/// notifier removes it after ~1.9s.
class LedgerToast extends StatelessWidget {
  final String text;
  const LedgerToast(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 12),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.toast,
        ),
        child: Text(
          text,
          style: AppText.ui(14, FontWeight.w700, color: AppColors.onBrand),
        ),
      ),
    );
  }
}
