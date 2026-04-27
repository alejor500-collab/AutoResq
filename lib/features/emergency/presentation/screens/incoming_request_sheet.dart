import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';

class IncomingRequestSheet extends ConsumerStatefulWidget {
  final Emergency emergency;

  const IncomingRequestSheet({super.key, required this.emergency});

  @override
  ConsumerState<IncomingRequestSheet> createState() =>
      _IncomingRequestSheetState();
}

class _IncomingRequestSheetState extends ConsumerState<IncomingRequestSheet> {
  Timer? _timer;
  int _seconds = 30;
  double _driverRating = 0;
  int _driverServices = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadDriverStats();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _seconds--);
      if (_seconds <= 0) {
        t.cancel();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  Future<void> _loadDriverStats() async {
    final driverId = widget.emergency.usuarioId;
    if (driverId.isEmpty) return;
    try {
      final data = await ref
          .read(supabaseClientProvider)
          .from(AppConstants.tableUsuarios)
          .select('calificacion_promedio, total_servicios')
          .eq('id', driverId)
          .single();
      if (!mounted) return;
      setState(() {
        _driverRating =
            (data['calificacion_promedio'] as num?)?.toDouble() ?? 0;
        _driverServices = (data['total_servicios'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyNotifierProvider);
    final emergency = widget.emergency;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ─── Handle ───────────────────────────────────────────────
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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Header: título + timer ────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'NUEVA SOLICITUD',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          _TimerChip(seconds: _seconds),
                        ],
                      ),
                      const Gap(12),

                      // ─── Chip clasificación IA ─────────────────────────
                      if (emergency.clasificacionIa != null)
                        _AiClassificationChip(tipo: emergency.clasificacionIa!),

                      const Gap(16),

                      // ─── Diagnóstico IA ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 13,
                                  color: AppColors.tertiary,
                                ),
                                Gap(6),
                                Text(
                                  'DIAGNÓSTICO IA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.tertiary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const Gap(8),
                            Text(
                              emergency.descripcion,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(14),

                      // ─── Tarjeta conductor ────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar + nombre + rating
                            Row(
                              children: [
                                UserAvatar(
                                  name: emergency.driverName ?? 'C',
                                  radius: 22,
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
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      const Gap(3),
                                      Row(
                                        children: [
                                          StarRating(
                                            rating: _driverRating,
                                            size: 14,
                                          ),
                                          const Gap(5),
                                          Text(
                                            '${AppHelpers.formatRating(_driverRating)} ($_driverServices servicios)',
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
                          ],
                        ),
                      ),
                      const Gap(12),

                      // ─── Ubicación ────────────────────────────────────
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              emergency.direccion ?? 'Riobamba, Ecuador',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(28),

                      // ─── Botón Aceptar ────────────────────────────────
                      AppButton(
                        label: '✓ Aceptar Servicio',
                        onPressed: emergencyState.isLoading
                            ? null
                            : () async {
                                final ok = await ref
                                    .read(emergencyNotifierProvider.notifier)
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
                      const Gap(10),

                      // ─── Botón Rechazar ───────────────────────────────
                      AppButton(
                        label: '✗ Rechazar',
                        onPressed: () => context.pop(),
                        variant: AppButtonVariant.outline,
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

// ─── Chip temporizador regresivo ──────────────────────────────────────────────

class _TimerChip extends StatelessWidget {
  final int seconds;

  const _TimerChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Text(
        '⏱ $seconds s',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.warning,
        ),
      ),
    );
  }
}

// ─── Chip clasificación IA ────────────────────────────────────────────────────

class _AiClassificationChip extends StatelessWidget {
  final String tipo;

  const _AiClassificationChip({required this.tipo});

  Color get _color {
    final lower = tipo.toLowerCase();
    if (lower.contains('mecán') || lower.contains('mecan')) {
      return AppColors.primary;
    }
    if (lower.contains('eléctri') || lower.contains('electri')) {
      return AppColors.tertiary;
    }
    return AppColors.secondary;
  }

  IconData get _icon {
    final lower = tipo.toLowerCase();
    if (lower.contains('mecán') || lower.contains('mecan')) {
      return Icons.build_rounded;
    }
    if (lower.contains('eléctri') || lower.contains('electri')) {
      return Icons.bolt_rounded;
    }
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _color),
          const Gap(6),
          Text(
            tipo,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
