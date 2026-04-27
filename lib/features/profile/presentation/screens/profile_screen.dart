import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/role_provider.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../providers/vehicle_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.value;
    final activeRole = ref.watch(activeRoleProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
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
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withOpacity(0.06),
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
                            splashColor: AppColors.primary.withOpacity(0.08),
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go(AppRoutes.driverHome),
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
                            letterSpacing: -0.5,
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
                  _ProfileHero(user: user, activeRole: activeRole),
                  const Gap(40),

                  // Stats Grid (Bento)
                  _StatsGrid(user: user),
                  const Gap(32),

                  // Vehicle Section
                  _VehicleSection(),
                  const Gap(32),

                  // Account Settings
                  _AccountSettings(
                    user: user,
                    activeRole: activeRole,
                    ref: ref,
                  ),
                  const Gap(24),

                  // Logout
                  GestureDetector(
                    onTap: () async {
                      final confirmed = await _confirmLogout(context);
                      if (confirmed == true && context.mounted) {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .logout();
                        context.go(AppRoutes.login);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
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
            child: AppBottomNavBar(
              currentIndex: 3,
              onTap: (i) {
                switch (i) {
                  case 0:
                    context.go(AppRoutes.driverHome);
                  case 1:
                    context.go(AppRoutes.emergencyHistory);
                  case 2:
                    break;
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
        content:
            const Text('\u00bfEstas seguro que deseas cerrar sesion?'),
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
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [AppColors.primary, AppColors.tertiary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
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
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit,
                      size: 16, color: Colors.white),
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
            letterSpacing: -0.5,
          ),
        ),
        const Gap(8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            'Premium Member',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final dynamic user;

  const _StatsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Total
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                    letterSpacing: -0.3,
                  ),
                ),
                const Gap(4),
                Text(
                  '${user.totalServices}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(16),
        // Completos
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Completos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const Gap(4),
                Text(
                  '${user.totalServices > 4 ? user.totalServices - 4 : 0}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(16),
        // Pendientes
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Pendientes',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const Gap(4),
                const Text(
                  '4',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Vehicle Section ──────────────────────────────────────────────────────────

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
              Text(
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
                    color: AppColors.primary.withOpacity(0.15),
                    style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 28, color: AppColors.primary),
                  ),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
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
                    color: AppColors.outlineVariant.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withOpacity(0.04),
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

class _AccountSettings extends StatelessWidget {
  final dynamic user;
  final String? activeRole;
  final WidgetRef ref;

  const _AccountSettings({
    required this.user,
    this.activeRole,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
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

        // Role switch (prominent)
        if (user.role != AppConstants.roleAdmin)
          _SettingsItem(
            icon: Icons.engineering,
            label: 'Cambiar a modo Tecnico',
            trailing: Icons.sync_alt,
            isProminent: true,
            onTap: () {
              final newRole =
                  (activeRole ?? user.role) == AppConstants.roleDriver
                      ? AppConstants.roleTechnician
                      : AppConstants.roleDriver;
              if (newRole == AppConstants.roleTechnician) {
                final hasSpecialty =
                    user.specialty != null && user.specialty!.isNotEmpty;
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
                if (user.isApproved != true) {
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
        const Gap(8),

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
          onTap: () {},
        ),
        const Gap(8),
        _SettingsItem(
          icon: Icons.shield,
          label: 'Seguridad y Privacidad',
          onTap: () {},
        ),
        const Gap(8),
        _SettingsItem(
          icon: Icons.notifications,
          label: 'Notificaciones',
          onTap: () {},
        ),
      ],
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
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  if (!isProminent)
                    BoxShadow(
                      color: AppColors.onSurface.withOpacity(0.04),
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
                  fontWeight:
                      isProminent ? FontWeight.w700 : FontWeight.w600,
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
