import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../map/presentation/widgets/map_widget.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';

class IncomingRequestSheet extends ConsumerWidget {
  final Emergency emergency;

  const IncomingRequestSheet({super.key, required this.emergency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyState = ref.watch(emergencyNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppConstants.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.warning_amber_rounded,
                                color: AppColors.error, size: 24),
                          ),
                          const Gap(12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '¡Nueva solicitud!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error,
                                ),
                              ),
                              Text(
                                AppHelpers.timeAgo(emergency.fecha),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Gap(20),

                      // Mini map
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 160,
                          child: AppMapWidget(
                            lat: emergency.lat ?? AppConstants.defaultLat,
                            lng: emergency.lng ?? AppConstants.defaultLng,
                            zoom: 15,
                            interactiveMap: false,
                            markers: [
                              emergencyMarker(emergency.lat ?? AppConstants.defaultLat, emergency.lng ?? AppConstants.defaultLng),
                            ],
                          ),
                        ),
                      ),
                      const Gap(16),

                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: AppColors.primary, size: 16),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              emergency.direccion ??
                                  'Riobamba, Ecuador',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(16),

                      // Driver info
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.1),
                              child: Text(
                                AppHelpers.getInitials(
                                    emergency.driverName ?? 'Conductor'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emergency.driverName ?? 'Conductor',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      StarRating(
                                        rating: 0.0,
                                        size: 14,
                                      ),
                                      const Gap(4),
                                      Text(
                                        AppHelpers.formatRating(
                                            0.0),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(16),

                      // Problem description
                      const Text(
                        'Descripción del problema',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        emergency.descripcion,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),

                      // AI Analysis
                      if (emergency.clasificacionIa != null) ...[
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, size: 14, color: AppColors.secondary),
                              const Gap(6),
                              Text(
                                emergency.clasificacionIa!,
                                style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Gap(28),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Rechazar',
                              onPressed: () => context.pop(),
                              variant: AppButtonVariant.outline,
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: AppButton(
                              label: 'Aceptar',
                              onPressed: emergencyState.isLoading
                                  ? null
                                  : () async {
                                      final ok = await ref
                                          .read(emergencyNotifierProvider
                                              .notifier)
                                          .acceptEmergency(emergency.id);
                                      if (!context.mounted) return;
                                      if (ok) {
                                        context.pop();
                                        context.push(
                                          AppRoutes.activeService,
                                          extra: emergency.id,
                                        );
                                      }
                                    },
                              isLoading: emergencyState.isLoading,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiChip extends StatelessWidget {
  final AiAnalysis analysis;

  const _AiChip({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              color: AppColors.secondary, size: 16),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.tipo,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  analysis.descripcionBreve,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
