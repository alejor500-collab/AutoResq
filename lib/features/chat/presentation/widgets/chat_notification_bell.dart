import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/providers/notification_provider.dart';

class ChatNotificationBell extends ConsumerWidget {
  final VoidCallback? onTap;
  final Color iconColor;
  final Color backgroundColor;
  final String tooltip;

  const ChatNotificationBell({
    super.key,
    this.onTap,
    this.iconColor = AppColors.secondary,
    this.backgroundColor = Colors.transparent,
    this.tooltip = 'Notificaciones',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);
    final badgeText =
        unreadNotifications > 99 ? '99+' : unreadNotifications.toString();

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: backgroundColor,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: tooltip,
                onPressed: onTap,
                splashRadius: 22,
                icon: Icon(
                  unreadNotifications > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: onTap == null
                      ? iconColor.withValues(alpha: 0.42)
                      : unreadNotifications > 0
                          ? AppColors.primary
                          : iconColor,
                  size: 23,
                ),
              ),
            ),
          ),
          if (unreadNotifications > 0)
            Positioned(
              right: 3,
              top: 3,
              child: IgnorePointer(
                child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ),
        ],
      ),
    );
  }
}
