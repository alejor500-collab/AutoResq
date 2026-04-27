import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/helpers.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';
import '../../features/profile/presentation/providers/vehicle_provider.dart';
import '../../core/constants/app_constants.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).value;
    final vehicle = ref.watch(vehicleProvider);
    final activeRole = ref.watch(activeRoleProvider);

    return Drawer(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ──────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user != null ? AppHelpers.getInitials(user.name) : 'U',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Usuario',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user?.role == AppConstants.roleTechnician
                                ? '⚙️ Técnico'
                                : user?.role == AppConstants.roleAdmin
                                    ? '👑 Admin'
                                    : '🚗 Conductor',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Navigation ───────────────────────────────────────────────
            _SectionLabel('NAVEGACIÓN'),
            _DrawerItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Inicio',
              onTap: () => Navigator.of(context).pop(),
            ),
            _DrawerItem(
              icon: Icons.history_outlined,
              activeIcon: Icons.history,
              label: 'Historial de Emergencias',
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.emergencyHistory);
              },
            ),
            if (user?.role != AppConstants.roleAdmin) ...[
              _DrawerItem(
                icon: Icons.report_problem_outlined,
                activeIcon: Icons.report_problem_rounded,
                label: 'Nueva Emergencia',
                color: AppColors.primary,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.createEmergency);
                },
              ),
            ],

            // ─── Admin ────────────────────────────────────────────────────
            if (user?.role == AppConstants.roleAdmin) ...[
              const SizedBox(height: 8),
              Divider(color: AppColors.surfaceContainerHigh, height: 1, thickness: 1),
              const SizedBox(height: 8),
              _SectionLabel('ADMINISTRACIÓN'),
              _DrawerItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Dashboard',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(AppRoutes.adminDashboard);
                },
              ),
              _DrawerItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people_rounded,
                label: 'Gestión de Usuarios',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.userManagement);
                },
              ),
              _DrawerItem(
                icon: Icons.verified_user_outlined,
                activeIcon: Icons.verified_user_rounded,
                label: 'Validar Técnicos',
                color: const Color(0xFF1E88E5),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.technicianValidation);
                },
              ),
              _DrawerItem(
                icon: Icons.monitor_heart_outlined,
                activeIcon: Icons.monitor_heart_rounded,
                label: 'Monitor de Emergencias',
                color: AppColors.error,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.emergencyMonitor);
                },
              ),
            ],

            const SizedBox(height: 8),
            Divider(color: AppColors.surfaceContainerHigh, height: 1, thickness: 1),
            const SizedBox(height: 8),

            // ─── Mi Cuenta ────────────────────────────────────────────────
            _SectionLabel('MI CUENTA'),
            _DrawerItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person_rounded,
              label: 'Mi Perfil',
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.profile);
              },
            ),
            _DrawerItem(
              icon: Icons.edit_outlined,
              activeIcon: Icons.edit,
              label: 'Editar Información',
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.editProfile);
              },
            ),
            _DrawerItem(
              icon: Icons.directions_car_outlined,
              activeIcon: Icons.directions_car_rounded,
              label: vehicle != null ? vehicle.displayName : 'Agregar Vehículo',
              subtitle: vehicle?.displaySub,
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.editVehicle);
              },
            ),

            // Role switch
            if (user?.role != AppConstants.roleAdmin) ...[
              const SizedBox(height: 8),
              Divider(color: AppColors.surfaceContainerHigh, height: 1, thickness: 1),
              const SizedBox(height: 8),
              _SectionLabel('MODO DE USO'),
              _DrawerItem(
                icon: Icons.engineering_outlined,
                activeIcon: Icons.engineering,
                label: (activeRole ?? user?.role) == AppConstants.roleDriver
                    ? 'Cambiar a Técnico'
                    : 'Cambiar a Conductor',
                color: AppColors.tertiary,
                onTap: () {
                  Navigator.of(context).pop();
                  final newRole =
                      (activeRole ?? user?.role) == AppConstants.roleDriver
                          ? AppConstants.roleTechnician
                          : AppConstants.roleDriver;
                  if (newRole == AppConstants.roleTechnician) {
                    final hasSpecialty = user?.specialty != null &&
                        user!.specialty!.isNotEmpty;
                    if (!hasSpecialty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Completa tu perfil técnico antes de activar este modo.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (user?.isApproved != true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tu perfil técnico está pendiente de aprobación.',
                          ),
                        ),
                      );
                      return;
                    }
                  }
                  ref.read(activeRoleProvider.notifier).switchTo(newRole);
                  if (newRole == AppConstants.roleDriver) {
                    context.go(AppRoutes.driverHome);
                  } else {
                    context.go(AppRoutes.technicianHome);
                  }
                },
              ),
            ],

            const Spacer(),
            Divider(color: AppColors.surfaceContainerHigh, height: 1, thickness: 1),

            // ─── App info ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'AutoResQ v1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.secondary.withOpacity(0.5),
                ),
              ),
            ),

            // Logout
            _DrawerItem(
              icon: Icons.logout,
              activeIcon: Icons.logout,
              label: 'Cerrar Sesión',
              color: AppColors.error,
              onTap: () async {
                Navigator.of(context).pop();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Cerrar sesión'),
                    content: const Text(
                        '¿Estás seguro que deseas cerrar sesión?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Salir',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await ref.read(authNotifierProvider.notifier).logout();
                  context.go(AppRoutes.welcome);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppColors.secondary.withOpacity(0.6),
        ),
      ),
    );
  }
}

// ─── Drawer item ─────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: (color ?? AppColors.primary).withOpacity(0.06),
        highlightColor: (color ?? AppColors.primary).withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: c, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: c.withOpacity(0.3), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
