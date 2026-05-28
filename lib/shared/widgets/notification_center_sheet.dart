import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/constants/app_colors.dart';
import '../providers/notification_provider.dart';

typedef NotificationTapHandler =
    FutureOr<void> Function(AppNotification notification);

Future<void> showNotificationCenterSheet({
  required BuildContext context,
  required WidgetRef ref,
  required NotificationTapHandler onNotificationTap,
}) async {
  final notifications = List<AppNotification>.from(
    ref.read(notificationsProvider).valueOrNull ?? const [],
  );
  final unreadCount = notifications.where((notification) => !notification.read).length;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.36,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            const Text(
              'Notificaciones',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.onSurface,
              ),
            ),
            const Gap(6),
            Text(
              unreadCount > 0
                  ? 'Tienes $unreadCount notificacion${unreadCount == 1 ? '' : 'es'} nueva${unreadCount == 1 ? '' : 's'} resaltada${unreadCount == 1 ? '' : 's'}.'
                  : 'Aqui veras actualizaciones, mensajes y novedades del servicio.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (unreadCount > 0) ...[
              const Gap(14),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    '$unreadCount nueva${unreadCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
            const Gap(18),
            if (notifications.isEmpty)
              const _EmptyNotificationPanel()
            else
              ...notifications.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NotificationTile(
                    notification: notification,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await onNotificationTap(notification);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  if (unreadCount > 0) {
    await ref.read(notificationActionsProvider).markAllRead();
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final Future<void> Function() onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (notification.type) {
      'solicitud_cancelada' || 'tecnico_cancelo' => AppColors.error,
      'nuevo_mensaje' => AppColors.primary,
      'nueva_solicitud' => AppColors.success,
      'servicio_finalizado' => AppColors.success,
      'solicitud_aceptada' => AppColors.warning,
      _ => AppColors.secondary,
    };
    final icon = switch (notification.type) {
      'solicitud_cancelada' || 'tecnico_cancelo' => Icons.cancel_rounded,
      'nuevo_mensaje' => Icons.chat_bubble_rounded,
      'nueva_solicitud' => Icons.notifications_active_rounded,
      'servicio_finalizado' => Icons.check_circle_rounded,
      'solicitud_aceptada' => Icons.check_circle_rounded,
      _ => Icons.notifications_rounded,
    };

    return Material(
      color: notification.read
          ? AppColors.surfaceContainerLow
          : color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Nueva',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      notification.timeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationPanel extends StatelessWidget {
  const _EmptyNotificationPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 28,
            color: AppColors.secondary,
          ),
          Gap(10),
          Text(
            'Sin novedades',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
            ),
          ),
          Gap(4),
          Text(
            'Cuando ocurra algo importante aparecera aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
