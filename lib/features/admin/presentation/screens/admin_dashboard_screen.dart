import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/admin_bottom_nav.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  void _reload() {
    final notifier = ref.read(adminNotifierProvider.notifier);
    Future.wait([
      notifier.loadStats(),
      notifier.loadPendingTechnicians(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotifierProvider);
    final user = ref.watch(authNotifierProvider).value;
    final stats = state.stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _AdminAppBar(
          onRefresh: _reload,
          onLogout: () async {
            await ref.read(authNotifierProvider.notifier).logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
        ),
      ),
      body: state.isLoading
          ? const _LoadingSkeleton()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                16,
                AppConstants.pagePadding,
                AppConstants.pagePadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroAnalyticsCard(
                    userName: user?.name.split(' ').first ?? 'Admin',
                    stats: stats,
                  ),
                  const Gap(20),
                  const _SectionTitle('KPIs de usuarios'),
                  const Gap(12),
                  _KpiGrid(stats: stats),
                  const Gap(24),
                  const _SectionTitle('Crecimiento y composicion'),
                  const Gap(12),
                  _GrowthAndRoleCard(stats: stats),
                  const Gap(24),
                  const _SectionTitle('Salud de la red tecnica'),
                  const Gap(12),
                  _TechnicianHealthCard(stats: stats),
                  const Gap(24),
                  const _SectionTitle('Alertas y decisiones'),
                  const Gap(12),
                  _AlertsCard(
                    stats: stats,
                    pendingTechnicians: state.pendingTechnicians,
                    onOpenUsers: () => context.go(AppRoutes.userManagement),
                    onOpenValidations: () =>
                        context.go(AppRoutes.technicianValidation),
                    onOpenMonitor: () => context.go(AppRoutes.emergencyMonitor),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: AdminBottomNav(
        selectedIndex: 0,
        onItemTapped: _onNavTap,
      ),
    );
  }
}

class _AdminAppBar extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const _AdminAppBar({
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.surfaceContainerLowest,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: const Row(
        children: [
          Icon(
            Icons.analytics_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          Gap(8),
          Text(
            'Analiticas de usuarios',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          tooltip: 'Actualizar',
        ),
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, color: AppColors.textPrimary),
          tooltip: 'Cerrar sesion',
        ),
      ],
    );
  }
}

class _HeroAnalyticsCard extends StatelessWidget {
  final String userName;
  final Map<String, dynamic> stats;

  const _HeroAnalyticsCard({
    required this.userName,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final totalUsers = stats['total_users'] as int? ?? 0;
    final newUsers30d = stats['new_users_30d'] as int? ?? 0;
    final completionRate = stats['completion_rate'] as int? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryContainer, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, $userName',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Vista ejecutiva para decisiones sobre usuarios y tecnicos.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(label: '$totalUsers usuarios totales'),
              _HeroPill(label: '+$newUsers30d nuevos en 30 dias'),
              _HeroPill(label: '$completionRate% de cierre operativo'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;

  const _HeroPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _KpiGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem(
        label: 'Usuarios activos',
        value: '${stats['active_users'] ?? 0}',
        helper: '${stats['disabled_users'] ?? 0} desactivados',
        color: AppColors.success,
        icon: Icons.people_alt_rounded,
      ),
      _KpiItem(
        label: 'Altas 7 dias',
        value: '${stats['new_users_7d'] ?? 0}',
        helper: '${stats['new_users_30d'] ?? 0} en 30 dias',
        color: AppColors.info,
        icon: Icons.trending_up_rounded,
      ),
      _KpiItem(
        label: 'Tecnicos aprobados',
        value: '${stats['approved_technicians'] ?? 0}',
        helper: '${stats['available_technicians'] ?? 0} disponibles',
        color: AppColors.warning,
        icon: Icons.build_circle_rounded,
      ),
      _KpiItem(
        label: 'Calidad tecnica',
        value:
            (stats['avg_technician_rating'] as double? ?? 0).toStringAsFixed(1),
        helper:
            '${(stats['avg_services_per_technician'] as double? ?? 0).toStringAsFixed(1)} servicios promedio',
        color: AppColors.secondary,
        icon: Icons.star_rounded,
      ),
      _KpiItem(
        label: 'Pendientes',
        value: '${stats['pending_validations'] ?? 0}',
        helper: '${stats['rejected_technicians'] ?? 0} rechazados',
        color: AppColors.error,
        icon: Icons.pending_actions_rounded,
      ),
      _KpiItem(
        label: 'Emergencias activas',
        value: '${stats['active_emergencies'] ?? 0}',
        helper: '${stats['completion_rate'] ?? 0}% completadas',
        color: AppColors.primary,
        icon: Icons.monitor_heart_rounded,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (_, index) => _KpiCard(item: items[index]),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final String helper;
  final Color color;
  final IconData icon;

  const _KpiItem({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
    required this.icon,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiItem item;

  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 20, color: item.color),
          ),
          const Spacer(),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const Gap(4),
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(2),
          Text(
            item.helper,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthAndRoleCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _GrowthAndRoleCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final growth = (stats['growth_7d'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final roles = (stats['role_distribution'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final maxCount = growth.fold<int>(
      1,
      (max, item) => ((item['count'] as int? ?? 0) > max)
          ? (item['count'] as int? ?? 0)
          : max,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Altas diarias de usuarios',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(14),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: growth.map((item) {
                final count = item['count'] as int? ?? 0;
                final label = item['label']?.toString() ?? '';
                final ratio = maxCount == 0 ? 0.0 : count / maxCount;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Gap(6),
                        Container(
                          height: 24 + (86 * ratio),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryContainer,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const Gap(8),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Gap(18),
          const Text(
            'Distribucion por rol',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: roles.map((item) {
              return _RoleChip(
                label: item['label']?.toString() ?? 'Rol',
                count: item['count'] as int? ?? 0,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final int count;

  const _RoleChip({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const Gap(8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianHealthCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _TechnicianHealthCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final approved = stats['approved_technicians'] as int? ?? 0;
    final available = stats['available_technicians'] as int? ?? 0;
    final pending = stats['pending_validations'] as int? ?? 0;
    final rejected = stats['rejected_technicians'] as int? ?? 0;
    final avgRating = stats['avg_technician_rating'] as double? ?? 0;
    final avgServices = stats['avg_services_per_technician'] as double? ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Aprobados',
                  value: '$approved',
                  color: AppColors.success,
                ),
              ),
              const Gap(10),
              Expanded(
                child: _MiniMetric(
                  label: 'Disponibles',
                  value: '$available',
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const Gap(10),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Pendientes',
                  value: '$pending',
                  color: AppColors.warning,
                ),
              ),
              const Gap(10),
              Expanded(
                child: _MiniMetric(
                  label: 'Rechazados',
                  value: '$rejected',
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const Gap(14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TextMetric(
                    title: 'Rating promedio',
                    value: avgRating.toStringAsFixed(1),
                    subtitle: avgRating >= 4
                        ? 'Calidad saludable'
                        : 'Conviene revisar soporte y supervision',
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _TextMetric(
                    title: 'Servicios por tecnico',
                    value: avgServices.toStringAsFixed(1),
                    subtitle: 'Carga media historica',
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

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const Gap(4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextMetric extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _TextMetric({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const Gap(6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const Gap(4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> pendingTechnicians;
  final VoidCallback onOpenUsers;
  final VoidCallback onOpenValidations;
  final VoidCallback onOpenMonitor;

  const _AlertsCard({
    required this.stats,
    required this.pendingTechnicians,
    required this.onOpenUsers,
    required this.onOpenValidations,
    required this.onOpenMonitor,
  });

  @override
  Widget build(BuildContext context) {
    final alerts = (stats['alerts'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final suggestions = (stats['suggestions'] as List? ?? const [])
        .map((item) => item.toString())
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: alerts.isEmpty
                ? [
                    const _AlertBadge(
                      label: 'Sin alertas criticas',
                      count: null,
                      tone: 'success',
                    ),
                  ]
                : alerts
                    .map(
                      (item) => _AlertBadge(
                        label: item['label']?.toString() ?? 'Alerta',
                        count: item['count'] as int?,
                        tone: item['tone']?.toString() ?? 'info',
                      ),
                    )
                    .toList(),
          ),
          const Gap(16),
          const Text(
            'Sugerencias para tomar accion',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(10),
          ...suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Usuarios',
                  icon: Icons.people_rounded,
                  onTap: onOpenUsers,
                ),
              ),
              const Gap(10),
              Expanded(
                child: _ActionButton(
                  label: pendingTechnicians.isNotEmpty
                      ? 'Validar'
                      : 'Tecnicos',
                  icon: Icons.verified_user_rounded,
                  onTap: onOpenValidations,
                ),
              ),
              const Gap(10),
              Expanded(
                child: _ActionButton(
                  label: 'Monitor',
                  icon: Icons.monitor_heart_rounded,
                  onTap: onOpenMonitor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertBadge extends StatelessWidget {
  final String label;
  final int? count;
  final String tone;

  const _AlertBadge({
    required this.label,
    required this.count,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      'danger' => AppColors.error,
      'warning' => AppColors.warning,
      'success' => AppColors.success,
      _ => AppColors.info,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        count == null ? label : '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const Gap(6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: AppColors.onSurface.withValues(alpha: 0.05),
        blurRadius: 14,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        16,
        AppConstants.pagePadding,
        AppConstants.pagePadding,
      ),
      child: Column(
        children: [
          ShimmerList(count: 1, itemHeight: 170),
          Gap(18),
          ShimmerList(count: 2, itemHeight: 130),
          Gap(18),
          ShimmerList(count: 2, itemHeight: 120),
        ],
      ),
    );
  }
}
