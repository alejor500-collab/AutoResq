import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/admin_bottom_nav.dart';
import '../providers/admin_provider.dart';

class EmergencyMonitorScreen extends ConsumerStatefulWidget {
  const EmergencyMonitorScreen({super.key});

  @override
  ConsumerState<EmergencyMonitorScreen> createState() =>
      _EmergencyMonitorScreenState();
}

class _EmergencyMonitorScreenState
    extends ConsumerState<EmergencyMonitorScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminNotifierProvider.notifier).loadAllEmergencies();
    });
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _activas {
    final all = ref.read(adminNotifierProvider).emergencies;
    return all
        .where((e) =>
            e['estado'] == AppConstants.statusPending ||
            e['estado'] == AppConstants.statusInProgress)
        .toList();
  }

  List<Map<String, dynamic>> get _historial {
    final all = ref.read(adminNotifierProvider).emergencies;
    return all
        .where((e) =>
            e['estado'] == AppConstants.statusCompleted ||
            e['estado'] == AppConstants.statusAttended ||
            e['estado'] == AppConstants.statusCancelled)
        .toList();
  }

  List<Map<String, dynamic>> get _sinTecnico {
    final all = ref.read(adminNotifierProvider).emergencies;
    return all.where((e) {
      if (e['estado'] != AppConstants.statusPending) return false;
      final asigs = e['asignaciones'] as List? ?? [];
      return asigs.isEmpty;
    }).toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _timeAgo(String? fechaStr) {
    if (fechaStr == null) return '';
    final date = DateTime.tryParse(fechaStr);
    if (date == null) return '';
    return AppHelpers.timeAgo(date);
  }

  int get _hoyCount {
    final now = AppHelpers.appNow();
    final all = ref.read(adminNotifierProvider).emergencies;
    return all.where((e) {
      final date = DateTime.tryParse(e['fecha'] as String? ?? '');
      if (date == null) return false;
      final appDate = AppHelpers.toAppTime(date);
      return appDate.year == now.year &&
          appDate.month == now.month &&
          appDate.day == now.day;
    }).length;
  }

  int get _atencionPct {
    final all = ref.read(adminNotifierProvider).emergencies;
    if (all.isEmpty) return 0;
    final done = all
        .where((e) =>
            e['estado'] == AppConstants.statusCompleted ||
            e['estado'] == AppConstants.statusAttended)
        .length;
    return ((done / all.length) * 100).round();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.adminDashboard);
        break;
      case 1:
        context.go(AppRoutes.userManagement);
        break;
      case 2:
        context.go(AppRoutes.technicianValidation);
        break;
      case 3:
        context.go(AppRoutes.emergencyMonitor);
        break;
      case 4:
        context.go(AppRoutes.adminReports);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotifierProvider);
    final list = _tabIndex == 0 ? _activas : _historial;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.adminDashboard);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: _MonitorAppBar(
            onBack: () => context.go(AppRoutes.adminDashboard),
            onRefresh: () =>
                ref.read(adminNotifierProvider.notifier).loadAllEmergencies(),
          ),
        ),
        body: Column(
          children: [
            _StatsStrip(
              activas: _activas.length,
              hoy: _hoyCount,
              sinTecnico: _sinTecnico.length,
              atencionPct: _atencionPct,
            ),
            _MonitorTabBar(
              selectedIndex: _tabIndex,
              activasCount: _activas.length,
              historialCount: _historial.length,
              onTabChanged: (i) => setState(() => _tabIndex = i),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: state.isLoading
                  ? const _LoadingState()
                  : list.isEmpty
                      ? _EmptyState(tabIndex: _tabIndex)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppConstants.pagePadding,
                            12,
                            AppConstants.pagePadding,
                            AppConstants.pagePadding,
                          ),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _EmergencyCard(
                            data: list[i],
                            timeAgoFn: _timeAgo,
                            onAssign: () =>
                                context.go(AppRoutes.technicianValidation),
                          ),
                        ),
            ),
          ],
        ),
        bottomNavigationBar: AdminBottomNav(
          selectedIndex: 3,
          onItemTapped: _onNavTap,
        ),
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────

class _MonitorAppBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _MonitorAppBar({required this.onBack, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.surfaceContainerLowest,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
        onPressed: onBack,
      ),
      title: Row(
        children: [
          Text(
            'Monitor de Emergencias',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0,
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
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          tooltip: 'Actualizar',
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

// ─── Stats Strip ──────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final int activas;
  final int hoy;
  final int sinTecnico;
  final int atencionPct;

  const _StatsStrip({
    required this.activas,
    required this.hoy,
    required this.sinTecnico,
    required this.atencionPct,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('Activas', '$activas', AppColors.error),
      _StatItem('Hoy', '$hoy', AppColors.info),
      _StatItem('Sin técnico', '$sinTecnico', AppColors.warning),
      _StatItem('Atención', '$atencionPct%', AppColors.statusInProgress),
    ];

    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: items
            .map((item) => Expanded(child: _StatTile(item: item)))
            .toList(),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final Color color;

  const _StatItem(this.label, this.value, this.color);
}

class _StatTile extends StatelessWidget {
  final _StatItem item;

  const _StatTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          item.value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: item.color,
            height: 1,
          ),
        ),
        const Gap(2),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Tab Bar ──────────────────────────────────────────────────────────────────

class _MonitorTabBar extends StatelessWidget {
  final int selectedIndex;
  final int activasCount;
  final int historialCount;
  final ValueChanged<int> onTabChanged;

  const _MonitorTabBar({
    required this.selectedIndex,
    required this.activasCount,
    required this.historialCount,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('Activas', activasCount),
      ('Historial', historialCount),
    ];

    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final label = tabs[i].$1;
          final count = tabs[i].$2;
          final isActive = selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(i),
              child: AnimatedContainer(
                duration: AppConstants.animFast,
                margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  count > 0 ? '$label ($count)' : label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Emergency Card ───────────────────────────────────────────────────────────

class _EmergencyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(String?) timeAgoFn;
  final VoidCallback onAssign;

  const _EmergencyCard({
    required this.data,
    required this.timeAgoFn,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final estado = data['estado'] as String? ?? AppConstants.statusPending;
    final descripcion = data['descripcion'] as String? ?? '';
    final fechaStr = data['fecha'] as String?;
    final clasificacionIa = data['clasificacion_ia'] as String?;
    final aiPriority = data['ai_priority'] as String?;
    final aiType = data['ai_emergency_type'] as String?;
    final aiSummary = data['ai_technician_summary'] as String?;

    final usuario = data['usuarios'] as Map<String, dynamic>? ?? {};
    final conductorNombre = usuario['nombre'] as String? ?? 'Conductor';

    final ubicList = data['ubicaciones'] as List? ?? [];
    final ubic = ubicList.isNotEmpty
        ? ubicList.first as Map<String, dynamic>
        : <String, dynamic>{};
    final direccion = ubic['direccion'] as String? ?? 'Ecuador';

    final asignList = data['asignaciones'] as List? ?? [];
    final hasAsignacion = asignList.isNotEmpty;
    final Map<String, dynamic>? asignacion =
        hasAsignacion ? asignList.first as Map<String, dynamic> : null;

    String? tecnicoNombre;
    String? asignEstado;
    if (asignacion != null) {
      final tecnico = asignacion['tecnicos'] as Map<String, dynamic>? ?? {};
      final tecUsuario = tecnico['usuarios'] as Map<String, dynamic>? ?? {};
      tecnicoNombre = tecUsuario['nombre'] as String?;
      asignEstado = asignacion['estado'] as String?;
    }

    final isPending = estado == AppConstants.statusPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    aiSummary?.isNotEmpty == true ? aiSummary! : descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const Gap(8),
                StatusChip(status: estado, fontSize: 10),
              ],
            ),
          ),
          // ── Conductor + ubicación ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const Gap(5),
                    Text(
                      conductorNombre,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const Gap(5),
                    Expanded(
                      child: Text(
                        direccion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Gap(6),
                    Text(
                      timeAgoFn(fechaStr),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                if ((aiType != null && aiType.isNotEmpty) ||
                    (clasificacionIa != null && clasificacionIa.isNotEmpty) ||
                    (aiPriority != null && aiPriority.isNotEmpty)) ...[
                  const Gap(6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _AiChip(label: aiType ?? clasificacionIa ?? 'IA'),
                        if (aiPriority != null && aiPriority.isNotEmpty)
                          _AiChip(label: aiPriority),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ── Footer ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: hasAsignacion && tecnicoNombre != null
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.build_rounded,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          tecnicoNombre,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (asignEstado != null)
                        StatusChip(status: asignEstado, fontSize: 10),
                    ],
                  )
                : isPending
                    ? SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onAssign,
                          icon: const Icon(Icons.person_add_rounded, size: 16),
                          label: Text(
                            'Asignar Técnico',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              size: 14, color: AppColors.textHint),
                          const Gap(6),
                          Text(
                            'Sin técnico asignado',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _AiChip extends StatelessWidget {
  final String label;

  const _AiChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 12, color: AppColors.info),
          const Gap(4),
          Text(
            'IA: $label',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading / Empty States ───────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppConstants.pagePadding),
      child: ShimmerList(count: 4, itemHeight: 160),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      message: tabIndex == 0
          ? 'Sin emergencias activas'
          : 'Sin historial registrado',
      subtitle: tabIndex == 0
          ? 'No hay emergencias pendientes o en proceso'
          : 'Las emergencias completadas aparecerán aquí',
      icon: tabIndex == 0
          ? Icons.check_circle_outline_rounded
          : Icons.history_rounded,
    );
  }
}
