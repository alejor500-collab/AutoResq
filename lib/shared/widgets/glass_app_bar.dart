import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showTitle;

  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.showTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64 + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withOpacity(0.06),
                blurRadius: 40,
                offset: const Offset(0, 40),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                if (leading != null)
                  leading!
                else
                  const SizedBox(width: 24),
                const Spacer(),
                if (showTitle)
                  Text(
                    title ?? 'AutoResQ',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                const Spacer(),
                if (actions != null)
                  Row(mainAxisSize: MainAxisSize.min, children: actions!)
                else
                  const SizedBox(width: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
