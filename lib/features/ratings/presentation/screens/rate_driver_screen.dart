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
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../shared/widgets/user_avatar.dart';

class RateDriverScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  final String? asignacionId;
  final String? technicianId;
  final String driverId;
  final String driverName;
  final String? vehicleInfo;
  final String? duration;
  final String? clasificacionIa;
  final String? amount;

  const RateDriverScreen({
    super.key,
    required this.emergencyId,
    this.asignacionId,
    this.technicianId,
    required this.driverId,
    required this.driverName,
    this.vehicleInfo,
    this.duration,
    this.clasificacionIa,
    this.amount,
  });

  @override
  ConsumerState<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends ConsumerState<RateDriverScreen> {
  int _stars = 0;
  final _reviewCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _resumenParams({int techRating = 0}) => {
        'driverName': widget.driverName,
        'vehicleInfo': widget.vehicleInfo,
        'amount': widget.amount,
        'duration': widget.duration,
        'clasificacionIa': widget.clasificacionIa,
        'techRating': techRating,
      };

  // ─── Actualiza estado en Supabase al finalizar ────────────────────────────
  Future<void> _runCompletionUpdates() async {
    final client = ref.read(supabaseClientProvider);

    if (widget.asignacionId != null && widget.asignacionId!.isNotEmpty) {
      await client
          .from(AppConstants.tableAsignaciones)
          .update({'estado': AppConstants.assignFinished}).eq(
              'id', widget.asignacionId!);
    }

    if (widget.emergencyId.isNotEmpty) {
      await client
          .from(AppConstants.tableEmergencias)
          .update({'estado': AppConstants.statusCompleted}).eq(
              'id', widget.emergencyId);
    }

    if (widget.technicianId != null && widget.technicianId!.isNotEmpty) {
      await client
          .from(AppConstants.tableTecnicos)
          .update({'disponible': true}).eq(
              'usuario_id', widget.technicianId!);
    }
  }

  // ─── Enviar calificación + updates + navegar ──────────────────────────────
  Future<void> _submit() async {
    if (_stars == 0) {
      AppHelpers.showSnackBar(context, 'Selecciona una calificación',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);

      await client.from(AppConstants.tableCalificaciones).insert({
        'emergencia_id': widget.emergencyId,
        'calificador_id': widget.technicianId ?? '',
        'calificado_id': widget.driverId,
        'puntuacion': _stars,
        if (_reviewCtrl.text.trim().isNotEmpty)
          'comentario': _reviewCtrl.text.trim(),
      });

      await _runCompletionUpdates();

      if (!mounted) return;
      context.go(AppRoutes.serviceCompleted, extra: _resumenParams(techRating: _stars));
    } catch (e) {
      if (!mounted) return;
      AppHelpers.showSnackBar(context, 'Error al enviar calificación',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Omitir: solo updates, sin calificación ───────────────────────────────
  Future<void> _skip() async {
    setState(() => _isLoading = true);
    try {
      await _runCompletionUpdates();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go(AppRoutes.serviceCompleted, extra: _resumenParams());
  }

  @override
  Widget build(BuildContext context) {
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
          'Calificar al cliente',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Contenido scrollable ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(AppConstants.pagePadding, 16,
                        AppConstants.pagePadding, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Gap(8),

                    // Avatar con borde primary
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary, width: 2.5),
                      ),
                      child: UserAvatar(
                        name: widget.driverName,
                        radius: 40,
                      ),
                    ),
                    const Gap(14),

                    // Nombre
                    Text(
                      widget.driverName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Gap(8),

                    // Pill vehículo (si existe)
                    if (widget.vehicleInfo != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          widget.vehicleInfo!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Gap(24),
                    ] else
                      const Gap(16),

                    // Card calificación
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusCard),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.onSurface.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '¿Cómo fue la experiencia\ncon este cliente?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                              height: 1.35,
                            ),
                          ),
                          const Gap(24),
                          InteractiveStarRating(
                            initialValue: _stars,
                            onChanged: (v) => setState(() => _stars = v),
                            size: 44,
                          ),
                          const Gap(24),
                          AppTextField(
                            label: 'Reseña (opcional)',
                            controller: _reviewCtrl,
                            maxLines: 4,
                            hint: 'Añade un comentario...',
                          ),
                        ],
                      ),
                    ),
                    const Gap(32),
                  ],
                ),
              ),
            ),

            // ─── Botones fijos al fondo ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePadding, 8, AppConstants.pagePadding, 20),
              child: Column(
                children: [
                  AppButton(
                    label: 'Enviar calificación',
                    onPressed: _isLoading ? null : _submit,
                    isLoading: _isLoading,
                  ),
                  const Gap(4),
                  TextButton(
                    onPressed: _isLoading ? null : _skip,
                    child: const Text(
                      'Omitir por ahora',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
