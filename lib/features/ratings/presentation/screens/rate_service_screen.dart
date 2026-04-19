import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../shared/widgets/user_avatar.dart';
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
  bool _submitted = false;

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

    final ok = await ref.read(ratingNotifierProvider.notifier).submitRating(
          emergenciaId: widget.emergencyId,
          calificadoId: widget.technicianId,
          puntuacion: _stars,
          comentario: _reviewCtrl.text.trim().isEmpty
              ? null
              : _reviewCtrl.text.trim(),
        );

    if (!mounted) return;

    if (ok) {
      setState(() => _submitted = true);
    } else {
      AppHelpers.showSnackBar(
        context,
        'No se pudo enviar la calificación',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratingState = ref.watch(ratingNotifierProvider);

    if (_submitted) return _buildSuccessPage(context);

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
              backgroundColor: AppColors.secondary,
            ),
            const Gap(16),
            Text(
              widget.technicianName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(32),

            // Review
            AppTextField(
              label: 'Deja una reseña (opcional)',
              controller: _reviewCtrl,
              maxLines: 3,
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
            const Gap(12),
            AppButton(
              label: 'Omitir',
              onPressed: () => context.go(AppRoutes.driverHome),
              variant: AppButtonVariant.ghost,
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

  Widget _buildSuccessPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded,
                  size: 80, color: Color(0xFFFFC107)),
              const Gap(24),
              const Text(
                '¡Gracias por tu calificación!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(12),
              const Text(
                'Tu opinión ayuda a mejorar el servicio',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Gap(32),
              AppButton(
                label: 'Volver al inicio',
                onPressed: () => context.go(AppRoutes.driverHome),
                height: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
