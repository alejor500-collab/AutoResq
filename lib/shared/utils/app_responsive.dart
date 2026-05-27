import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

abstract class AppResponsive {
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static double height(BuildContext context) => MediaQuery.sizeOf(context).height;

  static bool isCompact(BuildContext context) => width(context) < 380;

  static bool isTablet(BuildContext context) => width(context) >= 720;

  static bool isShort(BuildContext context) => height(context) < 700;

  static double horizontalPadding(BuildContext context) {
    if (isCompact(context)) return 16;
    if (isTablet(context)) return 32;
    return AppConstants.pagePadding;
  }

  static double sectionGap(BuildContext context) => isCompact(context) ? 18 : 24;

  static double titleSize(BuildContext context) => isCompact(context) ? 24 : 28;

  static double heroTitleSize(BuildContext context) => isCompact(context) ? 28 : 34;

  static double cardPadding(BuildContext context) => isCompact(context) ? 16 : 20;

  static double mapHeight(
    BuildContext context, {
    double compact = 220,
    double regular = 320,
    double tablet = 380,
  }) {
    if (isTablet(context)) return tablet;
    if (isCompact(context) || isShort(context)) return compact;
    return regular;
  }

  static double maxContentWidth(BuildContext context) {
    return isTablet(context) ? 640 : double.infinity;
  }

  static double actionMaxWidth(BuildContext context) {
    return isTablet(context) ? 420 : width(context) - horizontalPadding(context) * 2;
  }

  static EdgeInsets pageInsets(
    BuildContext context, {
    double top = 24,
    double bottom = 24,
  }) {
    final horizontal = horizontalPadding(context);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}

class AppResponsiveContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final Alignment alignment;

  const AppResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedMaxWidth = maxWidth ?? AppResponsive.maxContentWidth(context);
    if (resolvedMaxWidth == double.infinity) return child;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
        child: child,
      ),
    );
  }
}
