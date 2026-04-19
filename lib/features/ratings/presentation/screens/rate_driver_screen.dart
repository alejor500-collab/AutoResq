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

class RateDriverScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  final String driverId;
  final String driverName;

  const RateDriverScreen({
    super.key,
    required this.emergencyId,
    required this.driverId,
    required this.driverName,
  });

  @override
  ConsumerState<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends ConsumerState<RateDriverScreen> {
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
      AppHelpers.showSnackBar(context, 'Selecciona una calificación',
          isError: true);
      return;
    }

    final ok = await ref.read(ratingNotifierProvider.notifier).submitRating(
          emergenciaId: widget.emergencyId,
          calificadoId: widget.driverId,
          puntuacion: _stars,
          comentario: _reviewCtrl.text.trim().isEmpty
              ? null
              : _reviewCtrl.text.trim(),
        );

    if (!mounted) return;
    if (ok) setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final ratingState = ref.watch(ratingNotifierProvider);

    if (_submitted) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded,
                  size: 80, color: Color(0xFFFFC107)),
              const Gap(24),
              const Text('¡Calificación enviada!',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const Gap(32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AppButton(
                  label: 'Volver al inicio',
                  onPressed: () => context.go(AppRoutes.technicianHome),
                  height: 52,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.technicianHome),
        ),
        title: const Text(
          'Calificar conductor',
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
            UserAvatar(
              name: widget.driverName,
              radius: 40,
              backgroundColor: AppColors.primary,
            ),
            const Gap(16),
            Text(widget.driverName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const Gap(4),
            const Text('¿Cómo fue el conductor?',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            const Gap(32),
            InteractiveStarRating(
              onChanged: (v) => setState(() => _stars = v),
              size: 48,
            ),
            const Gap(32),
            AppTextField(
              label: 'Reseña (opcional)',
              controller: _reviewCtrl,
              maxLines: 3,
              hint: 'Comentarios sobre el conductor...',
            ),
            const Gap(32),
            AppButton(
              label: 'Enviar calificación',
              onPressed: _submit,
              isLoading: ratingState.isLoading,
              height: 52,
              prefixIcon:
                  const Icon(Icons.star, color: Colors.white, size: 18),
            ),
            const Gap(12),
            AppButton(
              label: 'Omitir',
              onPressed: () => context.go(AppRoutes.technicianHome),
              variant: AppButtonVariant.ghost,
            ),
          ],
        ),
      ),
    );
  }
}
