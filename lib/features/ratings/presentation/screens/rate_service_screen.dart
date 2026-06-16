import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../emergency/presentation/providers/emergency_provider.dart';
import '../providers/rating_provider.dart';

class RateServiceScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  final String technicianId;
  final String technicianName;

  const RateServiceScreen({
    super.key,
    required this.emergencyId,
    required this.technicianId,
    required this.technicianName,
  });

  @override
  ConsumerState<RateServiceScreen> createState() =>
      _RateServiceScreenState();
}

class _RateServiceScreenState extends ConsumerState<RateServiceScreen> {
  int _stars = 0;
  final _reviewCtrl = TextEditingController();

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      AppHelpers.showSnackBar(
        context,
        'Selecciona al menos 1 estrella',
        isError: true,
      );
      return;
    }

    final technicianUserId = await _resolveTechnicianUserId();
    if (!mounted) return;
    if (technicianUserId.isEmpty) {
      AppHelpers.showSnackBar(
        context,
        'No se encontro el tecnico de este servicio.',
        isError: true,
      );
      return;
    }

    final ok = await ref.read(ratingNotifierProvider.notifier).submitRating(
          emergenciaId: widget.emergencyId,
          calificadoId: technicianUserId,
          puntuacion: _stars,
          raterRole: 'driver',
          comentario: _reviewCtrl.text.trim().isEmpty
              ? null
              : _reviewCtrl.text.trim(),
          refreshCurrentUser: false,
        );

    if (!mounted) return;

    if (ok) {
      final emergencyNotifier =
          ref.read(emergencyNotifierProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(AppRoutes.driverHome);
        Future<void>.delayed(Duration.zero, () {
          emergencyNotifier.clearActiveEmergency();
        });
      });
    } else {
      AppHelpers.showSnackBar(
        context,
        'No se pudo enviar la calificacion: ${ref.read(ratingNotifierProvider).error ?? 'intenta nuevamente'}',
        isError: true,
      );
    }
  }

  Future<String> _resolveTechnicianUserId() async {
    final id = widget.technicianId;
    if (id.isEmpty) return id;

    try {
      final row = await ref
          .read(supabaseClientProvider)
          .from(AppConstants.tableTecnicos)
          .select('usuario_id')
          .eq('id', id)
          .maybeSingle();
      return row?['usuario_id']?.toString() ?? id;
    } catch (_) {
      return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratingState = ref.watch(ratingNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.driverHome),
        ),
        title: const Text(
          'Calificar servicio',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        child: Column(
          children: [
            const Gap(16),
            // Technician avatar
            UserAvatar(
              name: widget.technicianName,
              radius: 40,
              backgroundColor: AppColors.primaryFixed,
            ),
            const Gap(16),
            Text(
              widget.technicianName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Gap(4),
            const Text(
              '¿Cómo fue el servicio?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(32),

            // Star rating
            InteractiveStarRating(
              onChanged: (v) => setState(() => _stars = v),
              size: 48,
            ),
            const Gap(8),
            Text(
              _starLabel(_stars),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(32),

            // Review
            AppTextField(
              label: 'Deja una reseña (opcional)',
              controller: _reviewCtrl,
              maxLines: 3,
              maxLength: Validators.reviewMaxLength,
              validator: (value) => Validators.optionalText(
                value,
                maxLength: Validators.reviewMaxLength,
                fieldName: 'La resena',
              ),
              hint: 'Cuéntanos más sobre tu experiencia...',
            ),
            const Gap(32),

            AppButton(
              label: 'Enviar calificación',
              onPressed: _submit,
              isLoading: ratingState.isLoading,
              height: 52,
              prefixIcon: const Icon(Icons.star, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  String _starLabel(int stars) {
    switch (stars) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return '¡Excelente!';
      default:
        return 'Selecciona una calificación';
    }
  }
}
