import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double? height;
  final double? fontSize;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.prefixIcon,
    this.suffixIcon,
    this.height,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? 56.0;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: h,
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    switch (variant) {
      case AppButtonVariant.primary:
        return _PrimaryPillButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          fontSize: fontSize,
        );
      case AppButtonVariant.secondary:
        return _SecondaryPillButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          fontSize: fontSize,
        );
      case AppButtonVariant.outline:
        return _OutlinePillButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          prefixIcon: prefixIcon,
          fontSize: fontSize,
        );
      case AppButtonVariant.ghost:
        return _GhostButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          prefixIcon: prefixIcon,
          fontSize: fontSize,
        );
      case AppButtonVariant.danger:
        return _PrimaryPillButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          fontSize: fontSize,
          gradient: const LinearGradient(
            colors: [AppColors.error, Color(0xFF8B0000)],
          ),
        );
    }
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double? fontSize;
  final LinearGradient? gradient;

  const _PrimaryPillButton({
    required this.label,
    this.onPressed,
    required this.isLoading,
    this.prefixIcon,
    this.suffixIcon,
    this.fontSize,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9999),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (prefixIcon != null) ...[
                        prefixIcon!,
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize ?? 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (suffixIcon != null) ...[
                        const SizedBox(width: 10),
                        suffixIcon!,
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double? fontSize;

  const _SecondaryPillButton({
    required this.label,
    this.onPressed,
    required this.isLoading,
    this.prefixIcon,
    this.suffixIcon,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9999),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.onSurface,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (prefixIcon != null) ...[
                      prefixIcon!,
                      const SizedBox(width: 10),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: fontSize ?? 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (suffixIcon != null) ...[
                      const SizedBox(width: 10),
                      suffixIcon!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _OutlinePillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? prefixIcon;
  final double? fontSize;

  const _OutlinePillButton({
    required this.label,
    this.onPressed,
    required this.isLoading,
    this.prefixIcon,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: AppColors.surfaceContainerHigh),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (prefixIcon != null) ...[
                        prefixIcon!,
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: fontSize ?? 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? prefixIcon;
  final double? fontSize;

  const _GhostButton({
    required this.label,
    this.onPressed,
    required this.isLoading,
    this.prefixIcon,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: const StadiumBorder(),
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (prefixIcon != null) ...[
                  prefixIcon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize ?? 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}
