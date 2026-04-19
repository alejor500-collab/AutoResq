import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/admin_provider.dart';

class TechnicianValidationScreen extends ConsumerStatefulWidget {
  const TechnicianValidationScreen({super.key});

  @override
  ConsumerState<TechnicianValidationScreen> createState() =>
      _TechnicianValidationScreenState();
}

class _TechnicianValidationScreenState
    extends ConsumerState<TechnicianValidationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminNotifierProvider.notifier).loadPendingTechnicians();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Validacion de tecnicos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : state.pendingTechnicians.isEmpty
              ? const EmptyStateWidget(
                  message: 'No hay tecnicos pendientes',
                  subtitle: 'Todos los tecnicos han sido revisados',
                  icon: Icons.verified_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppConstants.pagePadding),
                  itemCount: state.pendingTechnicians.length,
                  itemBuilder: (context, i) {
                    final tech = state.pendingTechnicians[i];
                    final nombre = tech['usuarios']?['nombre'] as String? ??
                        'Tecnico';
                    final techId = tech['id'] as String;
                    return _TechCard(
                      technician: tech,
                      onApprove: () async {
                        final ok = await ref
                            .read(adminNotifierProvider.notifier)
                            .approveTechnician(techId);
                        if (context.mounted && ok) {
                          AppHelpers.showSnackBar(
                            context,
                            '$nombre aprobado',
                            isSuccess: true,
                          );
                        }
                      },
                      onReject: () async {
                        final ok = await ref
                            .read(adminNotifierProvider.notifier)
                            .rejectTechnician(techId);
                        if (context.mounted && ok) {
                          AppHelpers.showSnackBar(
                            context,
                            '$nombre rechazado',
                            isError: true,
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _TechCard extends StatelessWidget {
  final Map<String, dynamic> technician;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _TechCard({
    required this.technician,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final userData = technician['usuarios'] as Map<String, dynamic>?;
    final nombre = userData?['nombre'] as String? ?? 'Tecnico';
    final email = userData?['email'] as String? ?? '';
    final telefono = userData?['telefono'] as String? ?? '';
    final especialidad = technician['especialidad'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: nombre,
                radius: 26,
                backgroundColor: AppColors.secondary,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pendiente',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          if (telefono.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 14, color: AppColors.textSecondary),
                const Gap(6),
                Text(telefono,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            const Gap(6),
          ],
          if (especialidad.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.build_outlined,
                    size: 14, color: AppColors.textSecondary),
                const Gap(6),
                Text(especialidad,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            const Gap(6),
          ],
          const Gap(16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Rechazar',
                  onPressed: onReject,
                  variant: AppButtonVariant.outline,
                  height: 40,
                ),
              ),
              const Gap(10),
              Expanded(
                child: AppButton(
                  label: 'Aprobar',
                  onPressed: onApprove,
                  height: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
