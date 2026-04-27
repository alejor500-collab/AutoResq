import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../shared/widgets/status_chip.dart';

// Route path: /technician/service-completed
class ServiceCompletedScreen extends StatelessWidget {
  const ServiceCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final extra =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};

    final driverName = extra['driverName'] as String? ?? 'Cliente';
    final vehicleInfo = extra['vehicleInfo'] as String?;
    final duration = extra['duration'] as String?;
    final amount = extra['amount'] as String?;
    final techRating = (extra['techRating'] as num?)?.toInt() ?? 0;
    final emergencyType = extra['emergencyType'] as String?
        ?? extra['clasificacionIa'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Contenido scrollable ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePadding,
                  24,
                  AppConstants.pagePadding,
                  16,
                ),
                child: Column(
                  children: [
                    const Gap(16),

                    // ─── Ícono check ────────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.12),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withOpacity(0.20),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 80,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    const Gap(20),

                    // ─── Títulos ─────────────────────────────────────
                    const Text(
                      'Servicio Completado',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Gap(6),
                    const Text(
                      'Asistencia exitosa',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Gap(24),

                    // ─── Card resumen ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusCard),
                        border: Border.all(
                            color: AppColors.surfaceContainerHigh),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.onSurface.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusCard),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Acento verde superior
                            Container(
                              height: 4,
                              color: AppColors.success,
                            ),

                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── CLIENTE ──────────────────────
                                  _SectionLabel('CLIENTE'),
                                  const Gap(4),
                                  Text(
                                    driverName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  if (vehicleInfo != null) ...[
                                    const Gap(2),
                                    Text(
                                      vehicleInfo,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],

                                  const Gap(14),
                                  const _Divider(),
                                  const Gap(14),

                                  // ── TIPO DE FALLA + TIEMPO ────────
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _SectionLabel('TIPO DE FALLA'),
                                            const Gap(6),
                                            if (emergencyType != null)
                                              StatusChip(
                                                  status: emergencyType)
                                            else
                                              const Text(
                                                '—',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color:
                                                      AppColors.textSecondary,
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
                                            _SectionLabel('TIEMPO TOTAL'),
                                            const Gap(6),
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
                                      ),
                                    ],
                                  ),

                                  const Gap(14),
                                  const _Divider(),
                                  const Gap(14),

                                  // ── MONTO ACORDADO ────────────────
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLow,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AppColors
                                              .surfaceContainerHigh),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionLabel('MONTO ACORDADO'),
                                        const Gap(4),
                                        Text(
                                          '\$${amount ?? '0'}',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const Gap(4),
                                        const Text(
                                          'Pago directo acordado con el cliente',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Gap(14),
                                  const _Divider(),
                                  const Gap(14),

                                  // ── CALIFICACIONES ─────────────────
                                  _RatingRow(
                                    label: 'Tu calificación al cliente:',
                                    child: techRating > 0
                                        ? StarRating(
                                            rating: techRating.toDouble(),
                                            size: 18,
                                            activeColor:
                                                AppColors.primary,
                                          )
                                        : const Text(
                                            'Omitida',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                  ),
                                  const Gap(8),
                                  _RatingRow(
                                    label: 'Calificación recibida:',
                                    child: const Text(
                                      'Pendiente de calificación\ndel conductor',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(32),
                  ],
                ),
              ),
            ),

            // ─── Botón fijo al fondo ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePadding, 8, AppConstants.pagePadding, 20),
              child: AppButton(
                label: '⊞  Volver al Dashboard',
                onPressed: () => context.go(AppRoutes.technicianHome),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets internos ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.surfaceContainerHigh,
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _RatingRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurface,
            ),
          ),
          const Gap(8),
          Flexible(child: child),
        ],
      ),
    );
  }
}
