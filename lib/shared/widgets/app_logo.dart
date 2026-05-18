import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double height;
  final double? width;
  final BoxFit fit;
  final bool semanticLabel;

  const AppLogo({
    super.key,
    this.height = 72,
    this.width,
    this.fit = BoxFit.contain,
    this.semanticLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/autoresq_logo.png',
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
                  color: Color(0xFFE50914),
                  size: 34,
                ),
                SizedBox(width: 8),
                Text(
                  'AutoResQ',
                  style: TextStyle(
                    color: Color(0xFF061426),
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
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
