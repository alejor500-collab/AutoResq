import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final double fontSize;
  final IconData? icon;
  final bool compact;

  const StatusChip({
    super.key,
    required this.status,
    this.fontSize = 11,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppHelpers.statusColor(status);
    final label = AppHelpers.statusLabel(status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _containerColor(color),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: _foregroundColor(color)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _foregroundColor(color),
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Color _containerColor(Color color) {
    if (color == AppColors.success) return AppColors.successContainer;
    if (color == AppColors.warning) return AppColors.warningContainer;
    if (color == AppColors.error || color == AppColors.emergency) {
      return AppColors.emergencyContainer;
    }
    if (color == AppColors.primary) return AppColors.primaryFixed;
    return AppColors.disabledContainer;
  }

  Color _foregroundColor(Color color) {
    if (color == AppColors.success) return AppColors.onSuccessContainer;
    if (color == AppColors.warning) return AppColors.onWarningContainer;
    if (color == AppColors.error || color == AppColors.emergency) {
      return AppColors.onEmergencyContainer;
    }
    if (color == AppColors.primary) return AppColors.primaryContainer;
    return AppColors.onSecondaryContainer;
  }
}
