import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class AppFadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final double offsetY;
  final Duration duration;

  const AppFadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 14,
    this.duration = AppConstants.animMedium,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) return child;

    final delay = Duration(milliseconds: 38 * index);
    final totalDuration = duration + delay;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: totalDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final startAfterDelay = delay.inMilliseconds == 0
            ? 0.0
            : delay.inMilliseconds / totalDuration.inMilliseconds;
        final progress = value <= startAfterDelay
            ? 0.0
            : ((value - startAfterDelay) / (1 - startAfterDelay))
                .clamp(0.0, 1.0);

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AppStepSwitcher extends StatelessWidget {
  final Widget child;
  final Object value;

  const AppStepSwitcher({
    super.key,
    required this.child,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) return KeyedSubtree(key: ValueKey(value), child: child);

    return AnimatedSwitcher(
      duration: AppConstants.animMedium,
      reverseDuration: AppConstants.animFast,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }
}

class AppStaggeredColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  const AppStaggeredColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) {
    var visualIndex = 0;
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children.map((child) {
        if (child is SizedBox || child is GapPlaceholder) return child;
        return AppFadeSlideIn(
          index: visualIndex++,
          child: child,
        );
      }).toList(),
    );
  }
}

class GapPlaceholder extends StatelessWidget {
  final double height;

  const GapPlaceholder(this.height, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
