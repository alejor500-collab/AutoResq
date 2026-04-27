import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/user_avatar.dart';

// Route path: /technician/service-closure
class ServiceClosureScreen extends ConsumerStatefulWidget {
  const ServiceClosureScreen({super.key});

  @override
  ConsumerState<ServiceClosureScreen> createState() =>
      _ServiceClosureScreenState();
}

class _ServiceClosureScreenState extends ConsumerState<ServiceClosureScreen> {
  final _montoController = TextEditingController();

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extra =
        (ModalRoute.of(context)?.settings.arguments ?? {}) as Map<String, dynamic>;
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
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 40,
                        color: Color(0xFF2E7D32),
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
                        letterSpacing: -0.3,
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
                            color: AppColors.onSurface.withOpacity(0.07),
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
                                Column(
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
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                  ],
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
                                          Text(
                                            duration ?? '—',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.onSurface,
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
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 0),
                              child: Row(
                                children: [
                                  const Text(
                                    'Tipo de falla:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const Gap(8),
                                  StatusChip(status: clasificacionIa),
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
                                AppTextField(
                                  label: 'Monto acordado',
                                  hint: '0',
                                  controller: _montoController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      '\$',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const Gap(12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.payments_outlined,
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
                label: 'Confirmar y calificar cliente →',
                onPressed: () => context.push(
                  AppRoutes.rateDriver,
                  extra: {
                    'emergencyId': emergencyId,
                    'asignacionId': asignacionId,
                    'technicianId': technicianId,
                    'driverId': driverId,
                    'driverName': driverName,
                    'vehicleInfo': vehicleInfo,
                    'duration': duration,
                    'clasificacionIa': clasificacionIa,
                    'amount': _montoController.text,
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
