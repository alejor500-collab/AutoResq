import 'dart:async';
import 'dart:ui' as ui;

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
      child: _DrawerEntranceMotion(
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
                    if (isDriverMode) ...[
                      const _SectionDivider(),
                      const _SectionLabel('EMERGENCIAS'),
                      _DrawerItem(
                        icon: Icons.report_problem_outlined,
                        label: 'Nueva Emergencia',
                        color: AppColors.primary,
                        onTap: () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.push(AppRoutes.createEmergency);
                        },
                      ),
                    ] else if (isTechnicianMode) ...[
                      const _SectionDivider(),
                      const _SectionLabel('GESTION TECNICA'),
                      _DrawerItem(
                        icon: Icons.assignment_outlined,
                        label: 'Solicitudes Disponibles',
                        subtitle: 'Emergencias pendientes cerca de ti',
                        onTap: () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.pushReplacement(
                            AppRoutes.technicianHome,
                            extra: 1,
                          );
                        },
                      ),
                    ],
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
                        label: vehicle != null
                            ? vehicle.displayName
                            : 'Agregar Vehiculo',
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
                          onTap: () async {
                            final nextRole =
                                activeRole == AppConstants.roleDriver
                                    ? AppConstants.roleTechnician
                                    : AppConstants.roleDriver;
                            await _switchActiveRoleWithTransition(
                              context,
                              ref,
                              nextRole,
                            );
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
      ),
    );
  }

  List<Widget> _driverItems(BuildContext context) {
    return [
      _DrawerItem(
        icon: Icons.history_outlined,
        label: 'Historial',
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push(AppRoutes.emergencyHistory);
        },
      ),
      _DrawerItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Chat',
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push(AppRoutes.driverChatHistory);
        },
      ),
      _DrawerItem(
        icon: Icons.home_outlined,
        label: 'Inicio',
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.pushReplacement(AppRoutes.driverHome);
        },
      ),
      _DrawerItem(
        icon: Icons.storefront_outlined,
        label: 'Servicios',
        subtitle: 'Talleres, gasolineras y apoyo cercano',
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.pushReplacement(AppRoutes.driverHome, extra: 3);
        },
      ),
    ];
  }

  List<Widget> _technicianItems(BuildContext context) {
    return [
      _DrawerItem(
        icon: Icons.receipt_long_outlined,
        label: 'Historial',
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.pushReplacement(AppRoutes.technicianHome, extra: 0);
        },
      ),
      _DrawerItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Chat',
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.pushReplacement(AppRoutes.technicianHome, extra: 3);
        },
      ),
      _DrawerItem(
        icon: Icons.location_on_outlined,
        label: 'Inicio',
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.pushReplacement(AppRoutes.technicianHome, extra: 2);
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

class _DrawerEntranceMotion extends StatelessWidget {
  final Widget child;

  const _DrawerEntranceMotion({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-18 * (1 - value), 0),
            child: Transform.scale(
              scale: 0.985 + (0.015 * value),
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
    );
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
          Image.asset(
            'assets/images/autoresq_logo_light-Photoroom.png',
            height: 54,
            width: 210,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.high,
          ),
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

class DrawerBackdropBlur extends StatelessWidget {
  final bool visible;

  const DrawerBackdropBlur({
    super.key,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: visible ? 8 : 0,
            sigmaY: visible ? 8 : 0,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.textPrimary.withValues(alpha: 0.10),
                  AppColors.primary.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _switchActiveRoleWithTransition(
  BuildContext context,
  WidgetRef ref,
  String nextRole,
) async {
  final router = GoRouter.of(context);
  final drawerNavigator = Navigator.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  final activeRoleNotifier = ref.read(activeRoleProvider.notifier);
  if (drawerNavigator.canPop()) {
    drawerNavigator.pop();
  }
  await Future<void>.delayed(const Duration(milliseconds: 140));

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

Future<void> _switchToTechnician(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  final router = GoRouter.of(context);
  final drawerNavigator = Navigator.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  final user = ref.read(authNotifierProvider).value;
  if (user == null) return;
  final authNotifier = ref.read(authNotifierProvider.notifier);
  final activeRoleNotifier = ref.read(activeRoleProvider.notifier);
  final supabase = ref.read(supabaseClientProvider);
  if (drawerNavigator.canPop()) {
    drawerNavigator.pop();
  }
  await Future<void>.delayed(const Duration(milliseconds: 140));

  await showRoleSwitchTransition(
    overlay,
    AppConstants.roleTechnician,
    onMidpoint: () {
      final updated = user.copyWith(role: AppConstants.roleTechnician);
      authNotifier.refreshUser(updated);
      activeRoleNotifier.switchTo(AppConstants.roleTechnician);
      supabase
          .from(AppConstants.tableUsuarios)
          .update({'rol': AppConstants.roleTechnician})
          .eq('id', userId)
          .then((_) {}, onError: (_) {});
      router.go(AppRoutes.technicianHome);
    },
  );
}

Future<void> showRoleSwitchTransition(
  OverlayState overlay,
  String nextRole, {
  required FutureOr<void> Function() onMidpoint,
}) async {
  final toTechnician = nextRole == AppConstants.roleTechnician;
  final completed = Completer<void>();
  Timer? failsafe;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _RoleSwitchTransitionOverlay(
      toTechnician: toTechnician,
      onMidpoint: onMidpoint,
      onFinished: () {
        failsafe?.cancel();
        if (entry.mounted) {
          entry.remove();
        }
        if (!completed.isCompleted) completed.complete();
      },
    ),
  );
  overlay.insert(entry);
  failsafe = Timer(const Duration(seconds: 3), () {
    if (entry.mounted) {
      entry.remove();
    }
    if (!completed.isCompleted) completed.complete();
  });
  await completed.future;
}

class _RoleSwitchTransitionOverlay extends StatefulWidget {
  final bool toTechnician;
  final FutureOr<void> Function() onMidpoint;
  final VoidCallback onFinished;

  const _RoleSwitchTransitionOverlay({
    required this.toTechnician,
    required this.onMidpoint,
    required this.onFinished,
  });

  @override
  State<_RoleSwitchTransitionOverlay> createState() =>
      _RoleSwitchTransitionOverlayState();
}

class _RoleSwitchTransitionOverlayState
    extends State<_RoleSwitchTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _midpointCalled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 360),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _run();
  }

  Future<void> _run() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 24));
      if (!mounted) return;
      await _controller.forward();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!_midpointCalled) {
        _midpointCalled = true;
        await Future<void>.sync(widget.onMidpoint);
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
      }
      await Future<void>.delayed(const Duration(milliseconds: 280));
    } finally {
      if (mounted) {
        try {
          await _controller.reverse();
        } finally {
          widget.onFinished();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _opacity,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.72),
                  AppColors.primary.withValues(alpha: 0.22),
                  AppColors.tertiary.withValues(alpha: 0.18),
                ],
              ),
            ),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.9, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: _RoleSwitchTransitionCard(
                  toTechnician: widget.toTechnician,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSwitchTransitionCard extends StatefulWidget {
  final bool toTechnician;

  const _RoleSwitchTransitionCard({required this.toTechnician});

  @override
  State<_RoleSwitchTransitionCard> createState() =>
      _RoleSwitchTransitionCardState();
}

class _RoleSwitchTransitionCardState extends State<_RoleSwitchTransitionCard> {
  bool _active = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _active = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fromIcon = widget.toTechnician
        ? Icons.directions_car_rounded
        : Icons.engineering_rounded;
    final toIcon = widget.toTechnician
        ? Icons.engineering_rounded
        : Icons.directions_car_rounded;
    final title =
        widget.toTechnician ? 'Modo tecnico activado' : 'Modo conductor activo';
    final subtitle = widget.toTechnician
        ? 'Preparando solicitudes y disponibilidad'
        : 'Volviendo al mapa del conductor';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 286,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 82,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    width: _active ? 180 : 92,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutBack,
                    left: _active ? 44 : 94,
                    child: _RoleSwitchIconBubble(
                      icon: fromIcon,
                      selected: !_active,
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutBack,
                    right: _active ? 44 : 94,
                    child: _RoleSwitchIconBubble(
                      icon: toIcon,
                      selected: _active,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: _active ? 18 : 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              child: Text(title, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSwitchIconBubble extends StatelessWidget {
  final IconData icon;
  final bool selected;

  const _RoleSwitchIconBubble({
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      scale: selected ? 1.08 : 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.74),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.16 : 0.06),
              blurRadius: selected ? 18 : 8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: selected ? AppColors.primary : AppColors.secondary,
          size: 26,
        ),
      ),
    );
  }
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
