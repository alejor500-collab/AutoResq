import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';

class EmergencyHistoryScreen extends ConsumerStatefulWidget {
  const EmergencyHistoryScreen({super.key});

  @override
  ConsumerState<EmergencyHistoryScreen> createState() =>
      _EmergencyHistoryScreenState();
}

class _EmergencyHistoryScreenState
    extends ConsumerState<EmergencyHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authNotifierProvider).value;
      if (user != null) {
        ref
            .read(emergencyNotifierProvider.notifier)
            .loadDriverEmergencies(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emergencyNotifierProvider);

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
          'Historial de emergencias',
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
          : state.emergencies.isEmpty
              ? const EmptyStateWidget(
                  message: 'Sin emergencias registradas',
                  subtitle: 'Tu historial de servicios aparecerá aquí',
                  icon: Icons.history,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppConstants.pagePadding),
                  itemCount: state.emergencies.length,
                  itemBuilder: (context, i) {
                    return _HistoryCard(emergency: state.emergencies[i]);
                  },
                ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final Emergency emergency;

  const _HistoryCard({required this.emergency});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.emergency;

    return AnimatedContainer(
      duration: AppConstants.animFast,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppHelpers.statusColor(e.estado)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.car_repair,
                      color: AppHelpers.statusColor(e.estado),
                      size: 22,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(4),
                        Row(
                          children: [
                            Text(
                              AppHelpers.formatDate(e.fecha),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Gap(8),
                            StatusChip(status: e.estado),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.tecnicoNombre != null) ...[
                    _InfoRow(
                      icon: Icons.build_outlined,
                      label: 'Técnico',
                      value: e.tecnicoNombre!,
                    ),
                    const Gap(8),
                  ],
                  if (e.direccion != null) ...[
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Ubicación',
                      value: e.direccion!,
                    ),
                    const Gap(8),
                  ],
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Fecha',
                    value: AppHelpers.formatDateTime(e.fecha),
                  ),
                  if (e.clasificacionIa != null) ...[
                    const Gap(10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 14, color: AppColors.secondary),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              e.clasificacionIa!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const Gap(6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }
}
