import 'package:flutter/material.dart';

import '../theme/tokens.dart';

Duration _motion(BuildContext context, Duration d) =>
    MediaQuery.of(context).disableAnimations ? Duration.zero : d;

/// Fades a child in once when it is first mounted. Used for overlays/scrims.
class EnterFade extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const EnterFade({
    super.key,
    required this.child,
    this.duration = AppDurations.fade,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _motion(context, duration),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: child,
    );
  }
}

/// Slides a child up from below (by its own height) once when first mounted —
/// the bottom-sheet / picker entrance.
class EnterSlideUp extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const EnterSlideUp({
    super.key,
    required this.child,
    this.duration = AppDurations.sheet,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: _motion(context, duration),
      curve: AppDurations.easeOutExpo,
      builder: (_, v, child) =>
          FractionalTranslation(translation: Offset(0, v), child: child),
      child: child,
    );
  }
}
