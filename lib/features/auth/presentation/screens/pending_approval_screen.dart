import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/tecnico_status_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/technician_request_sheet.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).value;
    final isRejected =
        user?.verificationStatus == AppConstants.verificationRejected;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: isRejected
                      ? AppColors.errorContainer
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  isRejected
                      ? Icons.cancel_rounded
                      : Icons.hourglass_empty_rounded,
                  size: 48,
                  color: isRejected ? AppColors.error : AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isRejected ? 'Solicitud rechazada' : 'Cuenta en revisión',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isRejected ? AppColors.error : AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isRejected
                    ? 'Tu solicitud como técnico fue rechazada por el administrador.'
                    : 'Tu solicitud fue enviada con éxito. El administrador revisará tu cédula y te notificará cuando tu cuenta sea aprobada.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.secondary,
                  height: 1.6,
                ),
              ),
              if (isRejected && user?.rejectionReason != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Motivo:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user!.rejectionReason!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onErrorContainer,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(flex: 3),
              if (isRejected && user != null) ...[
                AppButton(
                  label: 'Enviar nueva solicitud',
                  onPressed: () async {
                    final submitted = await showTechnicianRequestSheet(
                      context,
                      user.id,
                      isResubmission: true,
                      currentSpecialty: user.specialty,
                    );
                    if (!context.mounted) return;
                    if (submitted == true) {
                      ref.invalidate(tecnicoStatusProvider);
                      context.go(AppRoutes.driverHome);
                    }
                  },
                  prefixIcon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AppButton(
                label: 'Usar como conductor',
                onPressed: () => context.go(AppRoutes.driverHome),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Cerrar sesión',
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).logout(),
                variant: AppButtonVariant.outline,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
