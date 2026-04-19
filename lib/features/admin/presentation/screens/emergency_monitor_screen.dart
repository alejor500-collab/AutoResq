import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../presentation/providers/admin_provider.dart';
import '../../../emergency/presentation/providers/emergency_provider.dart';
import '../../../emergency/domain/entities/emergency_entity.dart';

class EmergencyMonitorScreen extends ConsumerStatefulWidget {
  const EmergencyMonitorScreen({super.key});

  @override
  ConsumerState<EmergencyMonitorScreen> createState() =>
      _EmergencyMonitorScreenState();
}

class _EmergencyMonitorScreenState
    extends ConsumerState<EmergencyMonitorScreen> {
  String _filterStatus = 'todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(emergencyNotifierProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emergencyNotifierProvider);

    final filtered = state.emergencies.where((e) {
      return _filterStatus == 'todos' || e.estado == _filterStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Text(
              'Monitor de emergencias',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Gap(8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(emergencyNotifierProvider.notifier).loadAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusFilter(
                    label: 'Todas',
                    selected: _filterStatus == 'todos',
                    onTap: () => setState(() => _filterStatus = 'todos'),
                  ),
                  const Gap(8),
                  _StatusFilter(
                    label: 'Pendientes',
                    selected: _filterStatus == AppConstants.statusPending,
                    color: AppColors.statusPending,
                    onTap: () => setState(
                        () => _filterStatus = AppConstants.statusPending),
                  ),
                  const Gap(8),
                  _StatusFilter(
                    label: 'En proceso',
                    selected: _filterStatus == AppConstants.statusInProgress,
                    color: AppColors.statusInProgress,
                    onTap: () => setState(
                        () => _filterStatus = AppConstants.statusInProgress),
                  ),
                  const Gap(8),
                  _StatusFilter(
                    label: 'Atendidas',
                    selected: _filterStatus == AppConstants.statusAttended,
                    color: AppColors.statusAttended,
                    onTap: () => setState(
                        () => _filterStatus = AppConstants.statusAttended),
                  ),
                ],
              ),
            ),
          ),
          const Gap(8),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? EmptyStateWidget(
                        message: _filterStatus == 'todos'
                            ? 'No hay emergencias registradas'
                            : 'No hay emergencias con este estado',
                        icon: Icons.warning_amber_outlined,
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.all(AppConstants.pagePadding),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          return _EmergencyAdminCard(
                              emergency: filtered[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyAdminCard extends StatelessWidget {
  final Emergency emergency;

  const _EmergencyAdminCard({required this.emergency});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  emergency.descripcion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusChip(status: emergency.estado),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.textSecondary),
              const Gap(4),
              Text(
                emergency.driverName ?? 'Conductor',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              if (emergency.tecnicoNombre != null) ...[
                const Gap(12),
                const Icon(Icons.build_outlined,
                    size: 14, color: AppColors.secondary),
                const Gap(4),
                Text(
                  emergency.tecnicoNombre!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.secondary),
                ),
              ],
            ],
          ),
          const Gap(4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textSecondary),
              const Gap(4),
              Expanded(
                child: Text(
                  emergency.direccion ?? 'Riobamba, Ecuador',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              Text(
                AppHelpers.timeAgo(emergency.fecha),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _StatusFilter({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
