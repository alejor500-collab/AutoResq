import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'animated_pressable.dart';

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
        return _AnimatedPillButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          fontSize: fontSize,
        );
      case AppButtonVariant.secondary:
        return _AnimatedPillButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          fontSize: fontSize,
          style: _ButtonStyle.secondary,
        );
      case AppButtonVariant.outline:
        return _AnimatedPillButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          prefixIcon: prefixIcon,
          fontSize: fontSize,
          style: _ButtonStyle.outline,
        );
      case AppButtonVariant.ghost:
        return _AnimatedPillButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          prefixIcon: prefixIcon,
          fontSize: fontSize,
          style: _ButtonStyle.ghost,
        );
      case AppButtonVariant.danger:
        return _AnimatedPillButton(
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

enum _ButtonStyle { primary, secondary, outline, ghost }

class _AnimatedPillButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double? fontSize;
  final LinearGradient? gradient;
  final _ButtonStyle style;

  const _AnimatedPillButton({
    required this.label,
    this.onPressed,
    required this.isLoading,
    this.prefixIcon,
    this.suffixIcon,
    this.fontSize,
    this.gradient,
    this.style = _ButtonStyle.primary,
  });

  @override
  State<_AnimatedPillButton> createState() => _AnimatedPillButtonState();
}

class _AnimatedPillButtonState extends State<_AnimatedPillButton> {
  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: widget.onPressed,
      borderRadius: BorderRadius.circular(9999),
      pressedScale: 0.965,
      hoverScale: 1.012,
      duration: const Duration(milliseconds: 180),
      disabledOpacity: widget.isLoading ? 1 : 0.58,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(widget.isLoading),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (widget.style) {
      case _ButtonStyle.primary:
        return _primaryBody();
      case _ButtonStyle.secondary:
        return _secondaryBody();
      case _ButtonStyle.outline:
        return _outlineBody();
      case _ButtonStyle.ghost:
        return _ghostBody();
    }
  }

  Widget _primaryBody() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: widget.gradient ?? AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(child: _content(Colors.white)),
    );
  }

  Widget _secondaryBody() {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(9999),
      child: Center(child: _content(AppColors.onSurface)),
    );
  }

  Widget _outlineBody() {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: AppColors.surfaceContainerHigh),
        ),
        child: Center(child: _content(AppColors.onSurface)),
      ),
    );
  }

  Widget _ghostBody() {
    return Center(
      child: _content(AppColors.primary),
    );
  }

  Widget _content(Color textColor) {
    if (widget.isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: textColor,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.prefixIcon != null) ...[
          widget.prefixIcon!,
          const SizedBox(width: 10),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: textColor,
            fontSize: widget.fontSize ?? 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        if (widget.suffixIcon != null) ...[
          const SizedBox(width: 10),
          widget.suffixIcon!,
        ],
      ],
    );
  }
}
