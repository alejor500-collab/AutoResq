import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../emergency/domain/entities/emergency_entity.dart';
import '../../../emergency/presentation/providers/emergency_provider.dart';

class DriverChatHistoryScreen extends ConsumerWidget {
  const DriverChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(driverEmergencyHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => _handleBack(context),
        ),
        title: const Text(
          'Historial de chats',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(driverEmergencyHistoryProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => _ChatHistoryError(
          detail: error.toString(),
          onRetry: () => ref.invalidate(driverEmergencyHistoryProvider),
        ),
        data: (history) {
          final chats = history
              .where((emergency) => emergency.asignacionId?.isNotEmpty == true)
              .toList();

          if (chats.isEmpty) {
            return const _EmptyDriverChats();
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(driverEmergencyHistoryProvider),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                const _ChatHistoryIntro(),
                const Gap(14),
                ...chats.map(
                  (emergency) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DriverChatHistoryCard(
                      emergency: emergency,
                      onTap: () => context.push(
                        AppRoutes.driverChat,
                        extra: emergency.id,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.driverHome);
  }
}

class _ChatHistoryIntro extends StatelessWidget {
  const _ChatHistoryIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          Gap(10),
          Expanded(
            child: Text(
              'Puedes revisar conversaciones anteriores. Solo los servicios activos permiten enviar mensajes.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverChatHistoryCard extends StatelessWidget {
  final Emergency emergency;
  final VoidCallback onTap;

  const _DriverChatHistoryCard({
    required this.emergency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final technicianName = emergency.tecnicoNombre?.trim().isNotEmpty == true
        ? emergency.tecnicoNombre!.trim()
        : 'Tecnico asignado';
    final serviceName = emergency.pricingServiceName ??
        emergency.aiEmergencyType ??
        emergency.clasificacionIa ??
        'Servicio';
    final closed = _isClosed(emergency);
    final statusText = closed ? 'Solo lectura' : 'Chat activo';
    final statusColor = closed ? AppColors.textSecondary : AppColors.success;
    final dateText = AppHelpers.formatDateTime(emergency.fecha);

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              UserAvatar(
                name: technicianName,
                radius: 24,
                backgroundColor: AppColors.surfaceContainerHigh,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      technicianName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Gap(3),
                    Text(
                      serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      dateText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Gap(10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isClosed(Emergency emergency) {
    return emergency.estado == AppConstants.statusCompleted ||
        emergency.estado == AppConstants.statusCancelled ||
        emergency.asignacionEstado == AppConstants.assignFinished ||
        emergency.asignacionEstado == AppConstants.assignRejected;
  }
}

class _EmptyDriverChats extends StatelessWidget {
  const _EmptyDriverChats();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.secondary,
              size: 42,
            ),
            Gap(12),
            Text(
              'Sin chats todavia',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            Gap(6),
            Text(
              'Cuando un tecnico acepte una solicitud, la conversacion aparecera aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHistoryError extends StatelessWidget {
  final String detail;
  final VoidCallback onRetry;

  const _ChatHistoryError({
    required this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.secondary,
              size: 42,
            ),
            const Gap(12),
            const Text(
              'No se pudo cargar el historial de chats',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const Gap(6),
            Text(
              detail,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const Gap(14),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
