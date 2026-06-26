import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tokens.dart';

/// The on-screen numeric keypad that drives the amount field. Emits the key
/// pressed ('0'–'9', '.', or 'del').
class Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const Keypad({super.key, required this.onKey});

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '.',
    '0',
    'del',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 4; r++)
          Row(
            children: [
              for (var c = 0; c < 3; c++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _Key(value: _keys[r * 3 + c], onKey: onKey),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final String value;
  final ValueChanged<String> onKey;
  const _Key({required this.value, required this.onKey});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onKey(value),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.keypad,
          borderRadius: BorderRadius.circular(AppRadii.key),
        ),
        child: value == 'del'
            ? const Icon(
                Symbols.backspace_rounded,
                color: AppColors.muted,
                size: 20,
              )
            : Text(value, style: AppText.ui(23, FontWeight.w500)),
      ),
    );
  }
}
