import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/payment_methods.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/emergency_provider.dart';
import '../widgets/emergency_evidence_photos.dart';
import '../widgets/technician_offer_amount_sheet.dart';
import '../../domain/entities/emergency_entity.dart';

class IncomingRequestSheet extends ConsumerStatefulWidget {
  final Emergency emergency;

  const IncomingRequestSheet({super.key, required this.emergency});

  @override
  ConsumerState<IncomingRequestSheet> createState() =>
      _IncomingRequestSheetState();
}

class _IncomingRequestSheetState extends ConsumerState<IncomingRequestSheet> {
  static const int _initialSeconds = 180;
  Timer? _timer;
  int _seconds = _initialSeconds;
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

  void _showPendingRatingDialog(Map<String, dynamic> pendingRating) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Tienes una calificacion pendiente'),
          content: const Text(
            'Califica tu ultimo servicio para poder responder una nueva emergencia.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.push(
                  AppRoutes.rateDriver,
                  extra: {
                    'emergencyId':
                        pendingRating['emergency_id']?.toString() ?? '',
                    'driverId':
                        pendingRating['rated_user_id']?.toString() ?? '',
                    'driverName':
                        pendingRating['rated_user_name']?.toString() ??
                            'Conductor',
                  },
                );
              },
              child: const Text('Calificar ahora'),
            ),
          ],
        );
      },
    );
  }

  Future<double?> _promptOfferAmount(Emergency emergency) {
    final suggestedAmount = emergency.protectedTotal ?? emergency.estimatedTotal;
    return showTechnicianOfferAmountSheet(
      context,
      suggestedAmount: suggestedAmount,
      currentOfferAmount: emergency.myOfferedAmount,
      alreadyOffered: emergency.hasMyOffer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyNotifierProvider);
    final emergency = widget.emergency;
    final hasOffer = emergency.hasMyOffer;
    final currentUser = ref.watch(authNotifierProvider).value ??
        ref.watch(authStateProvider).valueOrNull;
    final isOwnRequest = currentUser?.id == emergency.usuarioId;
    final isSmallScreen = MediaQuery.sizeOf(context).height < 700;

    return DraggableScrollableSheet(
      initialChildSize: isSmallScreen ? 0.88 : 0.78,
      minChildSize: isSmallScreen ? 0.72 : 0.5,
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
                  padding: EdgeInsets.fromLTRB(
                    isSmallScreen ? 16 : 24,
                    8,
                    isSmallScreen ? 16 : 24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Header: título + timer ────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(
                            child: Text(
                              'NUEVA SOLICITUD',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Gap(10),
                          _CountdownChip(seconds: _seconds),
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
                            const Row(
                              children: [
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
                              emergency.aiTechnicianSummary?.isNotEmpty == true
                                  ? emergency.aiTechnicianSummary!
                                  : emergency.descripcion,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (emergency.aiPriority != null ||
                                emergency.aiDetectedRisks.isNotEmpty) ...[
                              const Gap(10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (emergency.aiPriority != null)
                                    _AiMetaChip(
                                      label: emergency.aiPriority!,
                                      icon: Icons.priority_high_rounded,
                                    ),
                                  if (emergency.aiEmergencyType != null)
                                    _AiMetaChip(
                                      label: emergency.aiEmergencyType!,
                                      icon: Icons.category_rounded,
                                    ),
                                  ...emergency.aiDetectedRisks
                                      .where((risk) => risk != 'none')
                                      .map(
                                        (risk) => _AiMetaChip(
                                          label: risk,
                                          icon: Icons.warning_amber_rounded,
                                        ),
                                      ),
                                ],
                              ),
                            ],
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
                                          Flexible(
                                            child: Text(
                                              '${AppHelpers.formatRating(_driverRating)} ($_driverServices servicios)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
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
                              emergency.direccion ?? 'Ecuador',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(16),
                      EmergencyEvidencePhotos(
                        photoUrls: emergency.evidencePhotoUrls,
                        title: 'Fotos enviadas por el conductor',
                        featured: true,
                      ),
                      if (emergency.evidencePhotoUrls.isNotEmpty)
                        const Gap(14),
                      _ProtectedPriceCard(emergency: emergency),
                      if (hasOffer) ...[
                        const Gap(12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.warningContainer,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_offer_rounded,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  emergency.myOfferedAmount == null
                                      ? 'Oferta enviada. Puedes actualizarla mientras la solicitud siga pendiente.'
                                      : 'Oferta enviada por ${AppHelpers.formatCurrency(emergency.myOfferedAmount!)}. Puedes actualizarla si lo necesitas.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Gap(20),

                      // ─── Botón de oferta ──────────────────────────────
                      AppButton(
                        label:
                            isOwnRequest
                                ? 'Solicitud propia'
                                : hasOffer
                                    ? 'Actualizar oferta'
                                    : 'Enviar oferta',
                        onPressed: emergencyState.isLoading || isOwnRequest
                            ? null
                            : () async {
                                final offeredAmount =
                                    await _promptOfferAmount(emergency);
                                if (!context.mounted ||
                                    offeredAmount == null) {
                                  return;
                                }
                                final ok = await ref
                                    .read(emergencyNotifierProvider.notifier)
                                    .createTechnicianOffer(
                                      emergency.id,
                                      offeredAmount: offeredAmount,
                                    );
                                if (!context.mounted) return;
                                if (ok) {
                                  context.pop();
                                  AppHelpers.showSnackBar(
                                    context,
                                    hasOffer
                                        ? 'Oferta actualizada. El conductor vera tu nuevo valor.'
                                        : 'Oferta enviada. Espera la eleccion del conductor.',
                                    isSuccess: true,
                                  );
                                } else {
                                  final pending = await ref
                                      .read(emergencyNotifierProvider.notifier)
                                      .getPendingRating('technician');
                                  if (!context.mounted) return;
                                  if (pending != null) {
                                    _showPendingRatingDialog(pending);
                                  } else {
                                    AppHelpers.showSnackBar(
                                      context,
                                          ref
                                                  .read(emergencyNotifierProvider)
                                                  .error ??
                                          'No se pudo enviar la oferta',
                                      isError: true,
                                    );
                                  }
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

class _ProtectedPriceCard extends StatelessWidget {
  final Emergency emergency;

  const _ProtectedPriceCard({required this.emergency});

  @override
  Widget build(BuildContext context) {
    final snapshot = emergency.priceSnapshot;
    final amount = emergency.protectedTotal ?? emergency.estimatedTotal;
    final serviceName = emergency.pricingServiceName ?? 'Servicio';
    final amountText =
        amount == null ? 'Revision pendiente' : AppHelpers.formatCurrency(amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONDICIONES DEL SERVICIO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
          const Gap(6),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTight = constraints.maxWidth < 300;
              final service = Text(
                serviceName,
                maxLines: isTight ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              );
              final amountWidget = FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  amountText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              );
              if (isTight) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    service,
                    const Gap(4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: amountWidget,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: service),
                  const Gap(10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: amountWidget,
                  ),
                ],
              );
            },
          ),
          const Gap(6),
          const Text(
            'Precio protegido. Extras solo con aprobacion del usuario.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const Gap(10),
          Row(
            children: [
              Icon(
                PaymentMethods.icon(emergency.paymentMethod),
                size: 16,
                color: AppColors.primary,
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  'Forma de pago: ${PaymentMethods.label(emergency.paymentMethod)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (snapshot?['includes_text'] is String) ...[
            const Gap(6),
            Text(
              snapshot!['includes_text'] as String,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiMetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _AiMetaChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.tertiary),
          const Gap(4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip temporizador regresivo ──────────────────────────────────────────────

// ignore: unused_element
class _TimerChip extends StatelessWidget {
  final int seconds;

  const _TimerChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
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

class _CountdownChip extends StatelessWidget {
  final int seconds;

  const _CountdownChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final minutes = safeSeconds ~/ 60;
    final remainingSeconds = safeSeconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 14,
            color: AppColors.warning,
          ),
          const Gap(5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

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
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _color),
          const Gap(6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              tipo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
