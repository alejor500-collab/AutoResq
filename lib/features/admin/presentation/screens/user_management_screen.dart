import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/admin_bottom_nav.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/admin_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends ConsumerState<UserManagementScreen> {
  String _searchQuery = '';
  String _filterRole = 'todos';

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.adminDashboard);
        break;
      case 1:
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminNotifierProvider.notifier).loadUsers();
    });
  }

  Future<void> _handleToggle(String id, bool currentActivo) async {
    final ok = await ref
        .read(adminNotifierProvider.notifier)
        .toggleUserActive(id, !currentActivo);
    if (!ok && mounted) {
      AppHelpers.showSnackBar(
        context,
        'No se pudo actualizar la cuenta',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotifierProvider);

    final filtered = state.users.where((u) {
      final name = (u['nombre'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      final role = u['rol'] as String? ?? '';
      final matchSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
      final matchRole = _filterRole == 'todos' || role == _filterRole;
      return matchSearch && matchRole;
    }).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.adminDashboard);
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AdminBottomNav(
        selectedIndex: 1,
        onItemTapped: _onNavTap,
      ),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go(AppRoutes.adminDashboard),
        ),
        title: const Text(
          'Gestion de usuarios',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const Gap(8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        selected: _filterRole == 'todos',
                        onTap: () =>
                            setState(() => _filterRole = 'todos'),
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: 'Conductores',
                        selected:
                            _filterRole == AppConstants.roleDriver,
                        onTap: () => setState(
                            () => _filterRole = AppConstants.roleDriver),
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: 'Tecnicos',
                        selected:
                            _filterRole == AppConstants.roleTechnician,
                        onTap: () => setState(() =>
                            _filterRole = AppConstants.roleTechnician),
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: 'Admins',
                        selected:
                            _filterRole == AppConstants.roleAdmin,
                        onTap: () => setState(
                            () => _filterRole = AppConstants.roleAdmin),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : filtered.isEmpty
                    ? const EmptyStateWidget(
                        message: 'No se encontraron usuarios',
                        icon: Icons.people_outline,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          return _UserCard(
                            user: filtered[i],
                            onToggleActive: () => _handleToggle(
                              filtered[i]['id'] as String,
                              filtered[i]['activo'] as bool? ?? true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      ),
    );
  }
}

enum _AccountStatus { active, pending, rejected, disabled }

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggleActive;

  const _UserCard({required this.user, required this.onToggleActive});

  _AccountStatus get _status {
    final activo = user['activo'] as bool? ?? true;
    if (!activo) return _AccountStatus.disabled;
    final tecnicoData = user['tecnicos'] as Map<String, dynamic>?;
    final estado = tecnicoData?['estado_verificacion'] as String?;
    if (estado == AppConstants.verificationPending) return _AccountStatus.pending;
    if (estado == AppConstants.verificationRejected) return _AccountStatus.rejected;
    return _AccountStatus.active;
  }

  Color _statusColor(_AccountStatus s) {
    switch (s) {
      case _AccountStatus.active:   return AppColors.success;
      case _AccountStatus.pending:  return AppColors.warning;
      case _AccountStatus.rejected: return AppColors.error;
      case _AccountStatus.disabled: return AppColors.textHint;
    }
  }

  String _statusLabel(_AccountStatus s) {
    switch (s) {
      case _AccountStatus.active:   return 'Activa';
      case _AccountStatus.pending:  return 'Pendiente';
      case _AccountStatus.rejected: return 'Rechazada';
      case _AccountStatus.disabled: return 'Deshabilitada';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleDriver:     return AppColors.primary;
      case AppConstants.roleTechnician: return AppColors.secondary;
      case AppConstants.roleAdmin:      return AppColors.warning;
      default:                          return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name     = user['nombre'] as String? ?? 'Usuario';
    final email    = user['email']  as String? ?? '';
    final role     = user['rol']    as String? ?? '';
    final avatarUrl = user['foto_url'] as String?;
    final activo   = user['activo'] as bool? ?? true;
    final status   = _status;
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          UserAvatar(imageUrl: avatarUrl, name: name, radius: 22),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _roleColor(role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              AppHelpers.roleLabel(role),
              style: TextStyle(
                color: _roleColor(role),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(4),
          IconButton(
            icon: Icon(
              activo ? Icons.toggle_on : Icons.toggle_off,
              color: activo ? statusColor : AppColors.textHint,
              size: 28,
            ),
            onPressed: onToggleActive,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
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
