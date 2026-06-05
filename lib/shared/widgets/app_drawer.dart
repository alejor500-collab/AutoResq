import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/helpers.dart';
import '../../features/profile/presentation/providers/vehicle_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/role_provider.dart';
import '../providers/tecnico_status_provider.dart';
import 'app_logo.dart';
import 'technician_request_sheet.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).value;
    final activeRole = ref.watch(activeRoleProvider) ?? user?.role;
    final isAdmin = user?.role == AppConstants.roleAdmin;
    final isDriverMode = activeRole == AppConstants.roleDriver && !isAdmin;
    final isTechnicianMode =
        activeRole == AppConstants.roleTechnician && !isAdmin;
    final vehicle = isDriverMode ? ref.watch(vehicleProvider) : null;
    final tecnicoStatus = user?.role == AppConstants.roleDriver
        ? ref.watch(tecnicoStatusProvider)
        : null;

    return Drawer(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DrawerHeader(
              name: user?.name ?? 'Usuario',
              email: user?.email ?? '',
              roleLabel: _roleLabel(activeRole),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  const _SectionLabel('NAVEGACION'),
                  if (isAdmin)
                    ..._adminItems(context)
                  else if (isTechnicianMode)
                    ..._technicianItems(context)
                  else
                    ..._driverItems(context),
                  const _SectionDivider(),
                  const _SectionLabel('MI CUENTA'),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Mi Perfil',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(AppRoutes.profile);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.edit_outlined,
                    label: 'Editar Informacion',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(AppRoutes.editProfile);
                    },
                  ),
                  if (isDriverMode)
                    _DrawerItem(
                      icon: Icons.directions_car_outlined,
                      label:
                          vehicle != null ? vehicle.displayName : 'Agregar Vehiculo',
                      subtitle: vehicle?.displaySub,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.editVehicle);
                      },
                    ),
                  if (!isAdmin) ...[
                    const _SectionDivider(),
                    const _SectionLabel('MODO DE USO'),
                    if (user?.role == AppConstants.roleTechnician)
                      _RoleSwitchItem(
                        activeRole: activeRole,
                        onTap: () {
                          Navigator.of(context).pop();
                          final nextRole = activeRole == AppConstants.roleDriver
                              ? AppConstants.roleTechnician
                              : AppConstants.roleDriver;
                          ref.read(activeRoleProvider.notifier).switchTo(nextRole);
                          context.go(nextRole == AppConstants.roleDriver
                              ? AppRoutes.driverHome
                              : AppRoutes.technicianHome);
                        },
                      )
                    else if (tecnicoStatus != null)
                      _TechnicianRequestStatus(
                        status: tecnicoStatus,
                        onRequest: () =>
                            _showTecnicoRequestSheet(context, ref, user!.id),
                        onSwitch: () =>
                            _switchToTechnician(context, ref, user!.id),
                      ),
                  ],
                ],
              ),
            ),
            const _SectionDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Text(
                'AutoResQ v1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.secondary.withValues(alpha: 0.5),
                ),
              ),
            ),
            _DrawerItem(
              icon: Icons.logout,
              label: 'Cerrar Sesion',
              color: AppColors.error,
              dense: true,
              onTap: () => _confirmLogout(context, ref),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Widget> _driverItems(BuildContext context) {
    return [
      _DrawerItem(
        icon: Icons.home_outlined,
        label: 'Inicio',
        onTap: () => Navigator.of(context).pop(),
      ),
      _DrawerItem(
        icon: Icons.history_outlined,
        label: 'Historial de Emergencias',
        onTap: () {
          Navigator.of(context).pop();
          context.push(AppRoutes.emergencyHistory);
        },
      ),
      _DrawerItem(
        icon: Icons.report_problem_outlined,
        label: 'Nueva Emergencia',
        color: AppColors.primary,
        onTap: () {
          Navigator.of(context).pop();
          context.push(AppRoutes.createEmergency);
        },
      ),
    ];
  }

  List<Widget> _technicianItems(BuildContext context) {
    return [
      _DrawerItem(
        icon: Icons.home_outlined,
        label: 'Panel Tecnico',
        onTap: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.technicianHome);
        },
      ),
      _DrawerItem(
        icon: Icons.assignment_outlined,
        label: 'Solicitudes Disponibles',
        subtitle: 'Emergencias pendientes cerca de ti',
        onTap: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.technicianHome);
        },
      ),
      _DrawerItem(
        icon: Icons.history_outlined,
        label: 'Historial de Servicios',
        onTap: () {
          Navigator.of(context).pop();
          context.push(AppRoutes.emergencyHistory);
        },
      ),
      _DrawerItem(
        icon: Icons.map_outlined,
        label: 'Servicios Cercanos',
        subtitle: 'Talleres, gasolineras y apoyo cercano',
        onTap: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.technicianHome);
        },
      ),
    ];
  }

  List<Widget> _adminItems(BuildContext context) {
    return [
      _DrawerItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        onTap: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.adminDashboard);
        },
      ),
      _DrawerItem(
        icon: Icons.people_outline,
        label: 'Gestion de Usuarios',
        onTap: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.userManagement);
        },
      ),
      _DrawerItem(
        icon: Icons.verified_user_outlined,
        label: 'Validar Tecnicos',
        color: AppColors.primary,
        onTap: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.technicianValidation);
        },
      ),
      _DrawerItem(
        icon: Icons.monitor_heart_outlined,
        label: 'Monitor de Emergencias',
        color: AppColors.error,
        onTap: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.emergencyMonitor);
        },
      ),
      _DrawerItem(
        icon: Icons.picture_as_pdf_outlined,
        label: 'Reportes Administrativos',
        color: AppColors.primary,
        onTap: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.adminReports);
        },
      ),
    ];
  }

  String _roleLabel(String? role) {
    switch (role) {
      case AppConstants.roleTechnician:
        return 'Tecnico';
      case AppConstants.roleAdmin:
        return 'Admin';
      default:
        return 'Conductor';
    }
  }
}

class _DrawerHeader extends StatelessWidget {
  final String name;
  final String email;
  final String roleLabel;

  const _DrawerHeader({
    required this.name,
    required this.email,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(height: 38, width: 150),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Text(
                    AppHelpers.getInitials(name),
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
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
          color: AppColors.secondary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: AppColors.surfaceContainerHigh,
        height: 1,
        thickness: 1,
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;
  final bool dense;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: (color ?? AppColors.primary).withValues(alpha: 0.06),
        highlightColor: (color ?? AppColors.primary).withValues(alpha: 0.04),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: dense ? 8 : 10,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: c.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSwitchItem extends StatelessWidget {
  final String? activeRole;
  final VoidCallback onTap;

  const _RoleSwitchItem({
    required this.activeRole,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final toTechnician = activeRole == AppConstants.roleDriver;
    return _DrawerItem(
      icon: toTechnician
          ? Icons.engineering_outlined
          : Icons.directions_car_outlined,
      label: toTechnician ? 'Cambiar a Tecnico' : 'Cambiar a Conductor',
      color: AppColors.tertiary,
      onTap: onTap,
    );
  }
}

class _TechnicianRequestStatus extends StatelessWidget {
  final AsyncValue<TecnicoStatus> status;
  final VoidCallback onRequest;
  final VoidCallback onSwitch;

  const _TechnicianRequestStatus({
    required this.status,
    required this.onRequest,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return status.when(
      loading: () => const _StatusTile(
        icon: Icons.engineering_outlined,
        label: 'Verificando solicitud...',
        color: AppColors.warning,
        trailing: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.warning,
          ),
        ),
      ),
      error: (_, __) => _DrawerItem(
        icon: Icons.engineering_outlined,
        label: 'Solicitar ser Tecnico',
        color: AppColors.tertiary,
        onTap: onRequest,
      ),
      data: (value) {
        if (value.aprobado) {
          return _DrawerItem(
            icon: Icons.engineering_outlined,
            label: 'Cambiar a Tecnico',
            color: AppColors.tertiary,
            onTap: onSwitch,
          );
        }
        if (value.pendiente) {
          return const _StatusTile(
            icon: Icons.hourglass_top_outlined,
            label: 'Solicitud en revision',
            subtitle: 'El administrador aprobara tu perfil',
            color: AppColors.warning,
          );
        }
        return _DrawerItem(
          icon: Icons.engineering_outlined,
          label: value.rechazado
              ? 'Re-solicitar ser Tecnico'
              : 'Solicitar ser Tecnico',
          color: AppColors.tertiary,
          onTap: onRequest,
        );
      },
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final Widget? trailing;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.color,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
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
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondary.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

void _showTecnicoRequestSheet(
  BuildContext context,
  WidgetRef ref,
  String userId,
) {
  showTechnicianRequestSheet(context, userId).then((submitted) {
    if (submitted == true && context.mounted) {
      Navigator.of(context).pop();
      context.go(AppRoutes.technicianPending);
    }
  });
}

void _switchToTechnician(BuildContext context, WidgetRef ref, String userId) {
  Navigator.of(context).pop();
  final user = ref.read(authNotifierProvider).value;
  if (user == null) return;
  final updated = user.copyWith(role: AppConstants.roleTechnician);
  ref.read(authNotifierProvider.notifier).refreshUser(updated);
  ref.read(activeRoleProvider.notifier).switchTo(AppConstants.roleTechnician);
  ref
      .read(supabaseClientProvider)
      .from(AppConstants.tableUsuarios)
      .update({'rol': AppConstants.roleTechnician})
      .eq('id', userId)
      .then((_) {}, onError: (_) {});
  context.go(AppRoutes.technicianHome);
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Cerrar sesion'),
      content: const Text('Estas seguro que deseas cerrar sesion?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Salir',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    Navigator.of(context).pop();
    await ref.read(authNotifierProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.welcome);
  }
}
