import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/admin_bottom_nav.dart';
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
    Future.wait([notifier.loadStats(), notifier.loadPendingTechnicians()]);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when navigating back to this screen
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _AdminAppBar(
          onLogout: () async {
            await ref.read(authNotifierProvider.notifier).logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
        ),
      ),
      body: Column(
        children: [
          _HeroBanner(userName: user?.name.split(' ').first ?? 'Admin'),
          Expanded(
            child: state.isLoading
                ? const _LoadingSkeleton()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.pagePadding,
                      20,
                      AppConstants.pagePadding,
                      AppConstants.pagePadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(title: 'Resumen del sistema'),
                        const Gap(12),
                        _StatsGrid(stats: state.stats),
                        const Gap(28),
                        _SectionHeader(
                          title: 'Técnicos pendientes',
                          actionLabel: state.pendingTechnicians.isNotEmpty
                              ? 'Ver todos'
                              : null,
                          onAction: () =>
                              context.go(AppRoutes.technicianValidation),
                        ),
                        const Gap(12),
                        _PendingTechniciansSection(
                          items: state.pendingTechnicians,
                          onViewAll: () =>
                              context.go(AppRoutes.technicianValidation),
                        ),
                        const Gap(28),
                        _SectionHeader(
                          title: 'Emergencias recientes',
                          actionLabel: 'Ver monitor',
                          onAction: () =>
                              context.go(AppRoutes.emergencyMonitor),
                        ),
                        const Gap(12),
                        _RecentEmergenciesSection(
                          activeCount:
                              state.stats['active_emergencies'] as int? ?? 0,
                          onViewAll: () =>
                              context.go(AppRoutes.emergencyMonitor),
                        ),
                        const Gap(8),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: AdminBottomNav(
        selectedIndex: 0,
        onItemTapped: _onNavTap,
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────

class _AdminAppBar extends StatelessWidget {
  final VoidCallback onLogout;

  const _AdminAppBar({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.primary,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 22,
          ),
          const Gap(8),
          Text(
            'Panel de Control',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
          tooltip: 'Cerrar sesión',
          onPressed: onLogout,
        ),
      ],
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String userName;

  const _HeroBanner({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryContainer, AppColors.primary],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido,',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  userName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        label: 'Total usuarios',
        value: stats['total_users']?.toString() ?? '0',
        icon: Icons.people_rounded,
        color: AppColors.info,
      ),
      _StatItem(
        label: 'Técnicos',
        value: stats['total_technicians']?.toString() ?? '0',
        icon: Icons.build_rounded,
        color: AppColors.warning,
      ),
      _StatItem(
        label: 'Pendientes',
        value: stats['pending_validations']?.toString() ?? '0',
        icon: Icons.pending_rounded,
        color: AppColors.secondary,
      ),
      _StatItem(
        label: 'Emergencias activas',
        value: stats['active_emergencies']?.toString() ?? '0',
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
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
        childAspectRatio: 1.45,
      ),
      itemBuilder: (_, i) => _StatCard(item: items[i]),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const Spacer(),
          Text(
            item.value,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const Gap(2),
          Text(
            item.label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pending Technicians ──────────────────────────────────────────────────────

class _PendingTechniciansSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onViewAll;

  const _PendingTechniciansSection({
    required this.items,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                size: 36,
                color: AppColors.textHint,
              ),
              const Gap(8),
              Text(
                'Sin técnicos pendientes',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayed = items.take(3).toList();

    return Column(
      children: [
        ...displayed.map(
          (tech) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TechnicianCard(tech: tech),
          ),
        ),
        if (items.length > 3)
          GestureDetector(
            onTap: onViewAll,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Ver ${items.length - 3} más',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  final Map<String, dynamic> tech;

  const _TechnicianCard({required this.tech});

  @override
  Widget build(BuildContext context) {
    final usuario = tech['usuarios'] as Map<String, dynamic>? ?? {};
    final nombre = usuario['nombre'] as String? ?? 'Técnico';
    final email = usuario['email'] as String? ?? '';
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'T';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Pendiente',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Emergencies ───────────────────────────────────────────────────────

class _RecentEmergenciesSection extends StatelessWidget {
  final int activeCount;
  final VoidCallback onViewAll;

  const _RecentEmergenciesSection({
    required this.activeCount,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onViewAll,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.error.withValues(alpha: 0.08),
              AppColors.error.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeCount == 0
                        ? 'Sin emergencias activas'
                        : '$activeCount emergencia${activeCount != 1 ? 's' : ''} activa${activeCount != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: activeCount > 0
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Toca para abrir el monitor en tiempo real',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.error.withValues(alpha: 0.6),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading Skeleton ─────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppConstants.pagePadding,
        20,
        AppConstants.pagePadding,
        AppConstants.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerList(count: 2, itemHeight: 100),
          Gap(24),
          ShimmerList(count: 3, itemHeight: 70),
        ],
      ),
    );
  }
}
