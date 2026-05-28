import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/emergency_provider.dart';

// Route path: /technician/service-closure
class ServiceClosureScreen extends ConsumerStatefulWidget {
  const ServiceClosureScreen({super.key});

  @override
  ConsumerState<ServiceClosureScreen> createState() =>
      _ServiceClosureScreenState();
}

class _ServiceClosureScreenState extends ConsumerState<ServiceClosureScreen> {
  bool _isCompleting = false;

  Future<void> _confirmCompletionAndRate({
    required String emergencyId,
    String? asignacionId,
    String? technicianId,
    required Map<String, dynamic> ratingArgs,
  }) async {
    if (_isCompleting) return;
    if (emergencyId.isEmpty) {
      AppHelpers.showSnackBar(
        context,
        'No se encontro el servicio para cerrar.',
        isError: true,
      );
      return;
    }

    setState(() => _isCompleting = true);
    final ok = await ref
        .read(emergencyNotifierProvider.notifier)
        .completeTechnicianService(
          emergencyId: emergencyId,
          assignmentId: asignacionId,
          technicianId: technicianId,
        );
    if (!mounted) return;
    setState(() => _isCompleting = false);

    if (!ok) {
      AppHelpers.showSnackBar(
        context,
        ref.read(emergencyNotifierProvider).error ??
            'No se pudo finalizar el servicio.',
        isError: true,
      );
      return;
    }

    ref.invalidate(activeTechnicianEmergencyProvider);
    ref.invalidate(technicianEmergencyHistoryProvider);
    context.pushReplacement(AppRoutes.rateDriver, extra: ratingArgs);
  }

  @override
  Widget build(BuildContext context) {
    final extra = (ModalRoute.of(context)?.settings.arguments ?? {})
        as Map<String, dynamic>;
    // Prefer GoRouter extra when available
    final routerExtra =
        GoRouterState.of(context).extra as Map<String, dynamic>?;
    final params = routerExtra ?? extra;

    final emergencyId = params['emergencyId'] as String? ?? '';
    final asignacionId = params['asignacionId'] as String?;
    final technicianId = params['technicianId'] as String?;
    final driverId = params['driverId'] as String? ?? '';
    final driverName = params['driverName'] as String? ?? 'Conductor';
    final vehicleInfo = params['vehicleInfo'] as String?;
    final duration = params['duration'] as String?;
    final clasificacionIa = params['clasificacionIa'] as String?;
    final amount = params['amount'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Cerrar Servicio',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.pagePadding,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Gap(16),

                    // ─── Ícono check verde 72 px ─────────────────────────
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.successContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 40,
                        color: AppColors.success,
                      ),
                    ),
                    const Gap(16),

                    // ─── Títulos ─────────────────────────────────────────
                    const Text(
                      '¿Todo listo?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                        letterSpacing: 0,
                      ),
                    ),
                    const Gap(6),
                    const Text(
                      'Confirma los detalles antes de cerrar',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Gap(24),

                    // ─── Card resumen ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusCard),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.onSurface.withValues(alpha: 0.07),
                            blurRadius: 16,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Cliente ──────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                            child: Row(
                              children: [
                                UserAvatar(
                                  name: driverName,
                                  radius: 24,
                                ),
                                const Gap(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                    const Text(
                                      'Cliente',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const Gap(2),
                                      Text(
                                        driverName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(
                              height: 1, color: AppColors.surfaceContainerHigh),

                          // ── Vehículo + Tiempo ─────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Vehículo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const Gap(4),
                                      Text(
                                        vehicleInfo ?? '—',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tiempo de servicio',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const Gap(4),
                                      Row(
                                        children: [
                                          const Icon(Icons.timer_outlined,
                                              size: 16,
                                              color: AppColors.onSurface),
                                          const Gap(4),
                                          Expanded(
                                            child: Text(
                                              duration ?? '—',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.onSurface,
                                              ),
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

                          // ── Tipo de falla ─────────────────────────────
                          if (clasificacionIa != null) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                              child: Row(
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Tipo de falla:',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const Gap(8),
                                  Flexible(
                                    child: StatusChip(status: clasificacionIa),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const Gap(14),
                          const Divider(
                              height: 1, color: AppColors.surfaceContainerHigh),

                          // ── Monto acordado ────────────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(
                                    AppConstants.borderRadiusCard),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'PRECIO PROTEGIDO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const Gap(4),
                                Text(
                                  amount == null || amount.isEmpty
                                      ? 'Revision pendiente'
                                      : '\$$amount',
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const Gap(12),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_outline,
                                        size: 14,
                                        color: AppColors.textSecondary),
                                    Gap(6),
                                    Text(
                                      'Cobro directo — efectivo o transferencia',
                                      style: TextStyle(
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
                    const Gap(32),
                  ],
                ),
              ),
            ),

            // ─── Botón fijo al fondo ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                8,
                AppConstants.pagePadding,
                24,
              ),
              child: AppButton(
                label: 'Finalizar y calificar cliente',
                isLoading: _isCompleting,
                onPressed: _isCompleting
                    ? null
                    : () => _confirmCompletionAndRate(
                          emergencyId: emergencyId,
                          asignacionId: asignacionId,
                          technicianId: technicianId,
                          ratingArgs: {
                            'emergencyId': emergencyId,
                            'asignacionId': asignacionId,
                            'technicianId': technicianId,
                            'driverId': driverId,
                            'driverName': driverName,
                            'vehicleInfo': vehicleInfo,
                            'duration': duration,
                            'clasificacionIa': clasificacionIa,
                            'amount': amount,
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
