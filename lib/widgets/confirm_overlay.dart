import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// An in-frame confirmation dialog. Rendered as a layer inside a sheet's own
/// Stack (so it stays within the 393×812 phone mock), unlike Material's
/// `showDialog`/`AlertDialog`, which render at the root window and spill outside.
class ConfirmOverlay extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const ConfirmOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCancel,
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.sheet,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.hairlineStrong),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.ui(16, FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: AppText.ui(13, FontWeight.w400,
                          color: AppColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _button(
                            cancelLabel,
                            onCancel,
                            bg: AppColors.keypad,
                            fg: AppColors.text,
                            borderColor: AppColors.hairlineStrong,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _button(
                            confirmLabel,
                            onConfirm,
                            bg: AppColors.expense.withValues(alpha: 0.16),
                            fg: AppColors.expense,
                            borderColor: AppColors.expense.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(
    String label,
    VoidCallback onTap, {
    required Color bg,
    required Color fg,
    required Color borderColor,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Text(label, style: AppText.ui(14, FontWeight.w700, color: fg)),
      ),
    );
  }
}
