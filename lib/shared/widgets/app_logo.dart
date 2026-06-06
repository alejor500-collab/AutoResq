import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum AppLogoVariant {
  wordmarkLight,
  withSloganLight,
  wordmarkDark,
  withSloganDark,
  isotype,
}

class AppLogo extends StatelessWidget {
  final double height;
  final double? width;
  final BoxFit fit;
  final bool semanticLabel;
  final AppLogoVariant variant;

  const AppLogo({
    super.key,
    this.height = 72,
    this.width,
    this.fit = BoxFit.contain,
    this.semanticLabel = true,
    this.variant = AppLogoVariant.wordmarkLight,
  });

  String get _assetPath => switch (variant) {
        AppLogoVariant.wordmarkLight =>
          'assets/images/autoresq_wordmark_light.png',
        AppLogoVariant.withSloganLight =>
          'assets/images/autoresq_logo_light.png',
        AppLogoVariant.wordmarkDark =>
          'assets/images/autoresq_wordmark_dark.png',
        AppLogoVariant.withSloganDark =>
          'assets/images/autoresq_logo_dark.png',
        AppLogoVariant.isotype => 'assets/images/autoresq_isotype.png',
      };

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      semanticLabel: semanticLabel ? 'AutoResQ' : null,
      excludeFromSemantics: !semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          height: height,
          width: width,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.car_repair_rounded,
                  color: AppColors.emergency,
                  size: 34,
                ),
                SizedBox(width: 8),
                Text(
                  'AutoResQ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
