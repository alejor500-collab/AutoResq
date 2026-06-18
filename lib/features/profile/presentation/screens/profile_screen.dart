import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/role_provider.dart';
import '../../../../shared/providers/tecnico_status_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/notification_center_sheet.dart';
import '../../../../shared/widgets/technician_request_sheet.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../providers/vehicle_provider.dart';

class ProfileServiceStats {
  final int total;
  final int attended;
  final int completed;
  final int pending;

  const ProfileServiceStats({
    required this.total,
    required this.attended,
    required this.completed,
    required this.pending,
  });

  static const empty = ProfileServiceStats(
    total: 0,
    attended: 0,
    completed: 0,
    pending: 0,
  );
}

final profileServiceStatsProvider = FutureProvider.autoDispose
    .family<ProfileServiceStats, ({String userId, bool isTechnician})>(
        (ref, args) async {
  final client = ref.read(supabaseClientProvider);

  if (args.isTechnician) {
    final technicianRows = await client
        .from(AppConstants.tableTecnicos)
        .select('id')
        .eq('usuario_id', args.userId)
        .limit(1);
    final technicianProfileId = (technicianRows as List).isEmpty
        ? args.userId
        : (technicianRows.first as Map)['id']?.toString() ?? args.userId;

    final rows = await client
        .from(AppConstants.tableAsignaciones)
        .select('estado, emergencias(estado)')
        .eq('tecnico_id', technicianProfileId);

    var attended = 0;
    var completed = 0;
    var pending = 0;

    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final assignmentStatus = row['estado'] as String?;
      final emergencyData = row['emergencias'];
      final emergencyStatus =
          emergencyData is Map ? emergencyData['estado'] as String? : null;
      final status = emergencyStatus ?? assignmentStatus;

      if (status == AppConstants.statusCompleted ||
          assignmentStatus == AppConstants.assignFinished) {
        completed++;
      } else if (status == AppConstants.statusAttended ||
          assignmentStatus == AppConstants.assignAttending) {
        attended++;
      } else if (status == AppConstants.statusPending ||
          status == AppConstants.statusInProgress ||
          assignmentStatus == AppConstants.assignAccepted ||
          assignmentStatus == AppConstants.assignEnRoute) {
        pending++;
      }
    }

    return ProfileServiceStats(
      total: pending + attended + completed,
      attended: attended,
      completed: completed,
      pending: pending,
    );
  }

  final rows = await client
      .from(AppConstants.tableEmergencias)
      .select('estado')
      .eq('usuario_id', args.userId);

  var attended = 0;
  var completed = 0;
  var pending = 0;

  for (final raw in rows as List) {
    final status = (raw as Map)['estado'] as String?;
    if (status == AppConstants.statusCompleted) {
      completed++;
    } else if (status == AppConstants.statusAttended) {
      attended++;
    } else if (status == AppConstants.statusPending ||
        status == AppConstants.statusInProgress) {
      pending++;
    }
  }

  return ProfileServiceStats(
    total: pending + attended + completed,
    attended: attended,
    completed: completed,
    pending: pending,
  );
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.value;
    final activeRole = ref.watch(activeRoleProvider);
    final effectiveRole = activeRole ?? user?.role;
    final isTechnicianMode = effectiveRole == AppConstants.roleTechnician &&
        user?.isTechnician == true &&
        user?.isApproved == true;
    final unreadChatCount =
        ref.watch(unreadChatCountProvider).valueOrNull ?? 0;

    if (user == null) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Glass AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 64 + MediaQuery.of(context).padding.top,
                  padding:
                      EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withValues(alpha: 0.06),
                        blurRadius: 40,
                        offset: const Offset(0, 40),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        // Back button with tactile feedback
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            splashColor:
                                AppColors.primary.withValues(alpha: 0.08),
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go(isTechnicianMode
                                    ? AppRoutes.technicianHome
                                    : AppRoutes.driverHome),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.arrow_back_ios_new,
                                  color: AppColors.secondary, size: 20),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Mi perfil',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onSurface,
                            letterSpacing: 0,
                          ),
                        ),
                        const Spacer(),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          child: Text(
                            AppHelpers.getInitials(user.name),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            top: 64 + MediaQuery.of(context).padding.top,
            bottom: 80 + MediaQuery.of(context).padding.bottom,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  // Profile Hero
                  _ProfileHero(user: user, activeRole: effectiveRole),
                  const Gap(24),
                  _ProfileStatsEntry(
                    user: user,
                    isTechnicianMode: isTechnicianMode,
                  ),
                  if (!isTechnicianMode) ...[
                    const Gap(12),
                    const _DriverRequestHistoryEntry(),
                  ],
                  const Gap(32),

                  // Vehicle Section
                  const _VehicleSection(),
                  const Gap(32),

                  // Account Settings
                  _AccountSettings(user: user),
                  const Gap(24),

                  // Logout
                  GestureDetector(
                    onTap: () async {
                      final confirmed = await _confirmLogout(context);
                      if (confirmed == true && context.mounted) {
                        final router = GoRouter.of(context);
                        await ref.read(authNotifierProvider.notifier).logout();
                        if (!context.mounted) return;
                        router.go(AppRoutes.login);
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout,
                              color: AppColors.secondary, size: 20),
                          Gap(12),
                          Text(
                            'Cerrar sesion',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Nav
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RoleHomeBottomNavBar(
              currentIndex: isTechnicianMode ? 3 : 4,
              isTechnician: isTechnicianMode,
              unreadCount: unreadChatCount,
              onTap: (i) {
                if (isTechnicianMode) {
                  switch (i) {
                    case 0:
                      context.go(AppRoutes.technicianHome, extra: 0);
                      break;
                    case 1:
                      context.go(AppRoutes.technicianHome, extra: 3);
                      break;
                    case 2:
                      context.go(AppRoutes.technicianHome, extra: 2);
                      break;
                    case 3:
                      break;
                  }
                } else {
                  switch (i) {
                    case 0:
                      context.go(AppRoutes.emergencyHistory);
                      break;
                    case 1:
                      context.go(AppRoutes.driverChatHistory);
                      break;
                    case 2:
                      context.go(AppRoutes.driverHome);
                      break;
                    case 3:
                      context.go(AppRoutes.driverHome, extra: 3);
                      break;
                    case 4:
                      break;
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text('\u00bfEstas seguro que deseas cerrar sesion?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Cerrar sesion',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Profile Hero ─────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final dynamic user;
  final String? activeRole;

  const _ProfileHero({required this.user, this.activeRole});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar with gradient ring and edit button
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 132,
              height: 132,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [AppColors.primary, AppColors.tertiary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        AppHelpers.getInitials(user.name),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.editProfile),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const Gap(24),
        Text(
          user.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

// ─── Profile Stats ────────────────────────────────────────────────────────────

class _ProfileStatsEntry extends ConsumerWidget {
  final AppUser user;
  final bool isTechnicianMode;

  const _ProfileStatsEntry({
    required this.user,
    required this.isTechnicianMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(
      profileServiceStatsProvider(
        (userId: user.id, isTechnician: isTechnicianMode),
      ),
    );

    return GestureDetector(
      onTap: () => _showProfileStatsSheet(
        context,
        statsAsync.valueOrNull ?? ProfileServiceStats.empty,
        isTechnicianMode,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: AppColors.primary,
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estadísticas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Gap(3),
                  Text(
                    statsAsync.isLoading
                        ? 'Actualizando resumen...'
                        : isTechnicianMode
                            ? 'Servicios, actividad y estados'
                            : 'Solicitudes, actividad y estados',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
            if (statsAsync.isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showProfileStatsSheet(
  BuildContext context,
  ProfileServiceStats stats,
  bool isTechnicianMode,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    builder: (context) => _ProfileStatsSheet(
      stats: stats,
      isTechnicianMode: isTechnicianMode,
    ),
  );
}

class _ProfileStatsSheet extends StatelessWidget {
  final ProfileServiceStats stats;
  final bool isTechnicianMode;

  const _ProfileStatsSheet({
    required this.stats,
    required this.isTechnicianMode,
  });

  @override
  Widget build(BuildContext context) {
    final metricRows = [
      (
        icon: Icons.receipt_long_rounded,
        label: 'Total registrado',
        value: stats.total,
        description: isTechnicianMode
            ? 'Servicios aceptados en tu historial.'
            : 'Solicitudes creadas desde tu cuenta.',
        color: AppColors.primary,
      ),
      (
        icon: Icons.pending_actions_rounded,
        label: 'Pendientes',
        value: stats.pending,
        description: 'Casos activos, en espera o en progreso.',
        color: AppColors.warning,
      ),
      (
        icon: Icons.handyman_rounded,
        label: 'Atendidas',
        value: stats.attended,
        description: isTechnicianMode
            ? 'Servicios actualmente marcados como atendidos.'
            : 'Solicitudes atendidas que aun no se cierran.',
        color: AppColors.info,
      ),
      (
        icon: Icons.check_circle_rounded,
        label: 'Completadas',
        value: stats.completed,
        description: 'Servicios finalizados correctamente.',
        color: AppColors.success,
      ),
    ];
    final completionRate =
        stats.total == 0 ? 0.0 : (stats.completed / stats.total).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estadísticas',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                  letterSpacing: 0,
                ),
              ),
              const Gap(6),
              Text(
                isTechnicianMode
                    ? 'Resumen de tu actividad como técnico.'
                    : 'Resumen de tus solicitudes como conductor.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Gap(22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Cierre de servicios',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '${(completionRate * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Gap(12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: completionRate,
                        minHeight: 9,
                        backgroundColor:
                            AppColors.outlineVariant.withValues(alpha: 0.28),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              ...metricRows.map(
                (metric) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StatsMetricRow(
                    icon: metric.icon,
                    label: metric.label,
                    value: metric.value,
                    description: metric.description,
                    color: metric.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsMetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String description;
  final Color color;

  const _StatsMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const Gap(3),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vehicle Section ──────────────────────────────────────────────────────────

class _DriverRequestHistoryEntry extends StatelessWidget {
  const _DriverRequestHistoryEntry();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.emergencyHistory),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            Gap(12),
            Expanded(
              child: Text(
                'Historial de solicitudes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleSection extends ConsumerWidget {
  const _VehicleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MI VEHÍCULO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.secondary,
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.editVehicle),
                child: Row(
                  children: [
                    Icon(
                      vehicle == null ? Icons.add_circle : Icons.edit,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const Gap(4),
                    Text(
                      vehicle == null ? 'Agregar' : 'Editar',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(12),

        // ── Empty state ──────────────────────────────────────────────
        if (vehicle == null)
          GestureDetector(
            onTap: () => context.push(AppRoutes.editVehicle),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 28, color: AppColors.primary),
                  ),
                  const Gap(14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sin vehículo registrado',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Gap(3),
                        Text(
                          'Toca para agregar tu vehículo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.secondary, size: 20),
                ],
              ),
            ),
          ),

        // ── Vehicle card ─────────────────────────────────────────────
        if (vehicle != null)
          GestureDetector(
            onTap: () => context.push(AppRoutes.editVehicle),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withValues(alpha: 0.04),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.directions_car,
                        size: 32, color: Colors.white),
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.displayName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          vehicle.displaySub,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined,
                      color: AppColors.secondary, size: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Account Settings ─────────────────────────────────────────────────────────

class _AccountSettings extends ConsumerWidget {
  final AppUser user;

  const _AccountSettings({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'AJUSTES DE CUENTA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.secondary,
            ),
          ),
        ),
        const Gap(12),

        // Role switch — usa tecnicoStatusProvider para conductores
        if (user.role != AppConstants.roleAdmin) ...[
          _TechnicianModeItem(user: user),
          const Gap(8),
        ],

        // Regular settings
        _SettingsItem(
          icon: Icons.person,
          label: 'Informacion Personal',
          onTap: () => context.push(AppRoutes.editProfile),
        ),
        const Gap(8),
        _SettingsItem(
          icon: Icons.payments,
          label: 'Metodos de Pago',
          onTap: () => context.push(AppRoutes.paymentMethods),
        ),
        const Gap(8),
        _SettingsItem(
          icon: Icons.shield,
          label: 'Seguridad y Privacidad',
          onTap: () => context.push(AppRoutes.securityPrivacy),
        ),
        const Gap(8),
        _SettingsItem(
          icon: Icons.notifications,
          label: 'Notificaciones',
          onTap: () => _openNotifications(context, ref),
        ),
      ],
    );
  }

  Future<void> _openNotifications(BuildContext context, WidgetRef ref) async {
    await showNotificationCenterSheet(
      context: context,
      ref: ref,
      onNotificationTap: (notification) async {
        if (!context.mounted) return;
        final referenceId = notification.referenceId;
        final activeRole = ref.read(activeRoleProvider) ?? user.role;
        final isTechnicianMode = activeRole == AppConstants.roleTechnician &&
            user.isTechnician &&
            user.isApproved;

        switch (notification.type) {
          case 'nuevo_mensaje':
            if (referenceId?.isEmpty != false) return;
            context.push(
              isTechnicianMode
                  ? AppRoutes.technicianChat
                  : AppRoutes.driverChat,
              extra: referenceId,
            );
            return;
          case 'nueva_solicitud':
          case 'solicitud_cancelada':
            context.go(
              isTechnicianMode ? AppRoutes.technicianHome : AppRoutes.driverHome,
              extra: isTechnicianMode ? 1 : null,
            );
            return;
          case 'solicitud_aceptada':
          case 'tecnico_en_ruta':
          case 'servicio_finalizado':
          case 'tecnico_cancelo':
            if (referenceId?.isEmpty != false) return;
            if (notification.type == 'servicio_finalizado' &&
                !isTechnicianMode) {
              final opened =
                  await _openCompletedServiceFromNotification(context, ref, referenceId!);
              if (!opened) return;
            }
            if (!context.mounted) return;
            context.push(AppRoutes.emergencyStatus, extra: referenceId);
            return;
          default:
            if (referenceId?.isEmpty != false) return;
            context.push(
              isTechnicianMode
                  ? AppRoutes.activeService
                  : AppRoutes.emergencyStatus,
              extra: referenceId,
            );
        }
      },
    );
  }

  Future<bool> _openCompletedServiceFromNotification(
    BuildContext context,
    WidgetRef ref,
    String emergencyId,
  ) async {
    final existing = await ref
        .read(supabaseClientProvider)
        .from(AppConstants.tableCalificaciones)
        .select('id')
        .eq('emergencia_id', emergencyId)
        .eq('calificador_id', user.id)
        .eq('rater_role', 'driver')
        .maybeSingle();

    if (!context.mounted) return false;
    if (existing != null) {
      AppHelpers.showSnackBar(
        context,
        'Solicitud no disponible. Este servicio ya fue calificado.',
        isError: true,
      );
      return false;
    }
    return true;
  }
}

// ─── Technician mode item ─────────────────────────────────────────────────────

class _TechnicianModeItem extends ConsumerWidget {
  final AppUser user;
  const _TechnicianModeItem({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Técnico registrado: solo alterna la vista activa
    if (user.isTechnician && user.isApproved) {
      final activeRole = ref.watch(activeRoleProvider);
      final goingToDriver =
          (activeRole ?? user.role) != AppConstants.roleDriver;
      return _SettingsItem(
        icon: goingToDriver ? Icons.directions_car : Icons.engineering,
        label: goingToDriver
            ? 'Cambiar a modo Conductor'
            : 'Cambiar a modo Técnico',
        trailing: Icons.sync_alt,
        isProminent: true,
        onTap: () async {
          final newRole = goingToDriver
              ? AppConstants.roleDriver
              : AppConstants.roleTechnician;
          await _switchRoleWithTransition(context, ref, newRole);
        },
      );
    }

    // Conductor: consulta estado real en tecnicos
    final statusAsync = ref.watch(tecnicoStatusProvider);
    return statusAsync.when(
      loading: () => _SettingsItem(
        icon: Icons.engineering,
        label: 'Verificando...',
        trailing: Icons.sync_alt,
        isProminent: false,
        onTap: () {},
      ),
      error: (_, __) => _SettingsItem(
        icon: Icons.engineering,
        label: 'Solicitar ser Técnico',
        trailing: Icons.sync_alt,
        isProminent: true,
        onTap: () => _openSheet(context, ref),
      ),
      data: (status) {
        if (status.aprobado) {
          return _SettingsItem(
            icon: Icons.engineering,
            label: 'Cambiar a modo Técnico',
            trailing: Icons.sync_alt,
            isProminent: true,
            onTap: () async => _switchRoleWithTransition(
              context,
              ref,
              AppConstants.roleTechnician,
            ),
          );
        }
        if (status.pendiente) {
          return const _PendingTechnicianSettingsTile();
        }
        // sinSolicitud o rechazado → abrir sheet con especialidad + cédula
        return _SettingsItem(
          icon: Icons.engineering,
          label: status.rechazado
              ? 'Re-solicitar ser Técnico'
              : 'Solicitar ser Técnico',
          trailing: Icons.sync_alt,
          isProminent: true,
          onTap: () => _openSheet(context, ref),
        );
      },
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref) {
    showTechnicianRequestSheet(context, user.id).then((submitted) {
      if (submitted == true && context.mounted) {
        ref.invalidate(tecnicoStatusProvider);
        ref.read(activeRoleProvider.notifier).switchTo(AppConstants.roleDriver);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitud enviada. Puedes seguir usando AutoResQ como conductor.',
            ),
          ),
        );
        context.go(AppRoutes.driverHome);
      }
    });
  }

  Future<void> _switchRoleWithTransition(
    BuildContext context,
    WidgetRef ref,
    String nextRole,
  ) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final router = GoRouter.of(context);
    final activeRoleNotifier = ref.read(activeRoleProvider.notifier);

    await showRoleSwitchTransition(
      overlay,
      nextRole,
      onMidpoint: () {
        activeRoleNotifier.switchTo(nextRole);
        router.go(nextRole == AppConstants.roleDriver
            ? AppRoutes.driverHome
            : AppRoutes.technicianHome);
      },
    );
  }
}

// ─── Pending technician tile (non-tappable) ───────────────────────────────────

class _PendingTechnicianSettingsTile extends StatelessWidget {
  const _PendingTechnicianSettingsTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.engineering_outlined,
                color: AppColors.warning, size: 20),
          ),
          const Gap(16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitud en revisión',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                Gap(2),
                Text(
                  'El administrador aprobará tu perfil',
                  style: TextStyle(fontSize: 12, color: AppColors.secondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Pendiente',
              style: TextStyle(
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

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailing;
  final bool isProminent;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.isProminent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isProminent
              ? AppColors.tertiaryContainer
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isProminent
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  if (!isProminent)
                    BoxShadow(
                      color: AppColors.onSurface.withValues(alpha: 0.04),
                      blurRadius: 4,
                    ),
                ],
              ),
              child: Icon(
                icon,
                size: 20,
                color: isProminent
                    ? AppColors.onTertiaryContainer
                    : AppColors.onSurface,
              ),
            ),
            const Gap(16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isProminent ? FontWeight.w700 : FontWeight.w600,
                  color: isProminent
                      ? AppColors.onTertiaryContainer
                      : AppColors.onSurface,
                ),
              ),
            ),
            Icon(
              trailing ?? Icons.chevron_right,
              color: isProminent
                  ? AppColors.onTertiaryContainer
                  : AppColors.secondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
