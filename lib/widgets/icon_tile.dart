import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A rounded, tinted square holding either a monogram letter or a category icon
/// — the avatar used in transaction rows, account rows and pickers.
class IconTile extends StatelessWidget {
  final double size;
  final double radius;
  final Color bg;
  final Color fg;
  final String? letter;
  final IconData? icon;
  final double glyphSize;
  final double fontSize;

  const IconTile({
    super.key,
    required this.size,
    required this.bg,
    required this.fg,
    this.radius = 9,
    this.letter,
    this.icon,
    this.glyphSize = 15,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: icon != null
          ? Icon(icon, color: fg, size: glyphSize)
          : Text(
              letter ?? '',
              style: AppText.ui(fontSize, FontWeight.w700, color: fg),
            ),
    );
  }
}
