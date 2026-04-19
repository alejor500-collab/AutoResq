import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../map/presentation/widgets/map_widget.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';

class ActiveServiceScreen extends ConsumerWidget {
  final String emergencyId;

  const ActiveServiceScreen({super.key, required this.emergencyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(watchEmergencyProvider(emergencyId));

    return stream.when(
      loading: () => const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(e.toString())),
      ),
      data: (emergency) => _ActiveServiceBody(emergency: emergency),
    );
  }
}

class _ActiveServiceBody extends ConsumerWidget {
  final Emergency emergency;

  const _ActiveServiceBody({required this.emergency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyState = ref.watch(emergencyNotifierProvider);
    final lat = emergency.lat ?? AppConstants.defaultLat;
    final lng = emergency.lng ?? AppConstants.defaultLng;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Servicio activo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined, color: AppColors.secondary),
            onPressed: () => context.push(
              AppRoutes.technicianChat,
              extra: emergency.id,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: AppMapWidget(
              lat: lat,
              lng: lng,
              zoom: 15,
              markers: [
                emergencyMarker(lat, lng),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Driver info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppColors.primary.withOpacity(0.1),
                          child: Text(
                            AppHelpers.getInitials(
                                emergency.driverName ?? 'C'),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emergency.driverName ?? 'Conductor',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                emergency.descripcion,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.push(
                            AppRoutes.technicianChat,
                            extra: emergency.id,
                          ),
                          icon: const Icon(Icons.chat_bubble_outline,
                              color: AppColors.secondary),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    const Text(
                      'Actualizar estado',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(12),
                    ..._buildStatusButtons(context, ref, emergency,
                        emergencyState.isLoading),

                    const Gap(16),

                    if (emergency.direccion != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.textSecondary),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              emergency.direccion!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusButtons(BuildContext context, WidgetRef ref,
      Emergency emergency, bool isLoading) {
    final assignStatus = emergency.asignacionEstado;

    final steps = [
      _TechStep(
        label: 'Aceptado',
        sublabel: 'Confirme la emergencia',
        icon: Icons.check_circle_outline,
        assignStatus: AppConstants.assignAccepted,
        emergencyStatus: AppConstants.statusInProgress,
        active: true,
      ),
      _TechStep(
        label: 'En ruta',
        sublabel: 'Me dirijo al conductor',
        icon: Icons.directions_car,
        assignStatus: AppConstants.assignEnRoute,
        emergencyStatus: AppConstants.statusInProgress,
        active: assignStatus == AppConstants.assignAccepted ||
            assignStatus == AppConstants.assignEnRoute ||
            assignStatus == AppConstants.assignAttending,
      ),
      _TechStep(
        label: 'Atendiendo',
        sublabel: 'Estoy trabajando en el vehiculo',
        icon: Icons.build,
        assignStatus: AppConstants.assignAttending,
        emergencyStatus: AppConstants.statusAttended,
        active: assignStatus == AppConstants.assignEnRoute ||
            assignStatus == AppConstants.assignAttending,
      ),
      _TechStep(
        label: 'Finalizado',
        sublabel: 'Servicio completado',
        icon: Icons.done_all,
        assignStatus: AppConstants.assignFinished,
        emergencyStatus: AppConstants.statusCompleted,
        active: assignStatus == AppConstants.assignAttending,
      ),
    ];

    return steps.map((step) {
      final isCurrent = assignStatus == step.assignStatus;
      final isDone = _isDone(assignStatus, step.assignStatus);

      return Opacity(
        opacity: step.active || isDone ? 1 : 0.4,
        child: GestureDetector(
          onTap: step.active && !isDone && !isLoading
              ? () => _updateStatus(
                  context, ref, emergency, step.emergencyStatus,
                  assignStatus: step.assignStatus)
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.success.withOpacity(0.06)
                  : isCurrent
                      ? AppColors.secondary.withOpacity(0.08)
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDone
                    ? AppColors.success.withOpacity(0.3)
                    : isCurrent
                        ? AppColors.secondary.withOpacity(0.3)
                        : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : step.icon,
                  color: isDone
                      ? AppColors.success
                      : isCurrent
                          ? AppColors.secondary
                          : AppColors.textHint,
                  size: 22,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDone
                              ? AppColors.success
                              : isCurrent
                                  ? AppColors.secondary
                                  : AppColors.textPrimary,
                        ),
                      ),
                      Text(step.sublabel,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (!isDone && step.active)
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  bool _isDone(String? current, String step) {
    final order = [
      AppConstants.assignAccepted,
      AppConstants.assignEnRoute,
      AppConstants.assignAttending,
      AppConstants.assignFinished,
    ];
    if (current == null) return false;
    final ci = order.indexOf(current);
    final si = order.indexOf(step);
    return ci > si;
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    Emergency emergency,
    String status, {
    required String assignStatus,
  }) async {
    await ref
        .read(emergencyNotifierProvider.notifier)
        .updateStatus(emergency.id, status);

    if (!context.mounted) return;

    if (assignStatus == AppConstants.assignFinished) {
      context.pushReplacement(
        AppRoutes.rateDriver,
        extra: {
          'emergencyId': emergency.id,
          'driverId': emergency.usuarioId,
          'driverName': emergency.driverName ?? 'Conductor',
        },
      );
    }
  }
}

class _TechStep {
  final String label;
  final String sublabel;
  final IconData icon;
  final String assignStatus;
  final String emergencyStatus;
  final bool active;

  const _TechStep({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.assignStatus,
    required this.emergencyStatus,
    required this.active,
  });
}
