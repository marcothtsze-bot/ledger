import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Wraps a set of rows in a single rounded, hairline-bordered group with thin
/// separators showing through between rows (the iOS-style inset list look).
/// Each child supplies its own opaque background.
class GroupedCard extends StatelessWidget {
  final List<Widget> children;
  const GroupedCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 2));
      spaced.add(children[i]);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.hairlineSoft,
          border: Border.all(color: AppColors.hairlineSoft),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: spaced),
      ),
    );
  }
}
