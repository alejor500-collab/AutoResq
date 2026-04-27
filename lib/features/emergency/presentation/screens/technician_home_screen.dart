import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/role_provider.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../map/presentation/widgets/map_widget.dart';
import '../providers/emergency_provider.dart';

class TechnicianHomeScreen extends ConsumerStatefulWidget {
  const TechnicianHomeScreen({super.key});

  @override
  ConsumerState<TechnicianHomeScreen> createState() =>
      _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends ConsumerState<TechnicianHomeScreen> {
  final _mapController = MapController();
  int _navIndex = 0;
  bool? _isAvailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(authNotifierProvider).value;
      if (user?.isApproved != true) return;
      await ref.read(mapNotifierProvider.notifier).getCurrentLocation();
      ref.read(emergencyNotifierProvider.notifier).loadPendingEmergencies();
    });
  }

  void _onNavTap(int index) {
    setState(() => _navIndex = index);
    switch (index) {
      case 1:
        context.push(AppRoutes.emergencyHistory);
      case 3:
        context.push(AppRoutes.profile);
    }
  }

  Future<void> _toggleAvailability(bool val) async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    setState(() => _isAvailable = val);
    try {
      await ref
          .read(supabaseClientProvider)
          .from(AppConstants.tableTecnicos)
          .update({'disponible': val}).eq('usuario_id', user.id);
      ref.read(technicianAvailableProvider.notifier).state = val;
    } catch (_) {
      setState(() => _isAvailable = !val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar la disponibilidad'),
          ),
        );
      }
    }
  }

  Widget _buildProfileCard({
    required String specialty,
    required bool isApproved,
    required bool isAvailable,
    required double rating,
    required int totalServices,
  }) {
    final chipColor = isApproved ? AppColors.success : AppColors.warning;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  specialty,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Chip(
                  label: Text(isApproved ? '✓ Verificado' : '⏳ Pendiente'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: chipColor,
                  ),
                  backgroundColor: chipColor.withOpacity(0.10),
                  side: BorderSide(color: chipColor.withOpacity(0.30)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Gap(8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Disponible',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isAvailable
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
              Switch(
                value: isAvailable,
                onChanged: _toggleAvailability,
                activeColor: AppColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const Gap(8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const Gap(2),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Text(
                '($totalServices servicios)',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pending approval UI ───────────────────────────────────────────────────

  Widget _buildPendingBody(BuildContext context, String? specialty) {
    final profileIncomplete =
        specialty == null || specialty.trim().isEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 48,
                color: AppColors.warning,
              ),
            ),
            const Gap(32),
            const Text(
              'Solicitud enviada',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(12),
            const Text(
              'Estamos verificando tus datos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            const Text(
              'Te avisaremos cuando tu cuenta técnica sea aprobada.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
              ),
              child: Column(
                children: [
                  _PendingStep(
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    label: 'Registro completado',
                  ),
                  const Gap(12),
                  _PendingStep(
                    icon: Icons.manage_search_outlined,
                    color: AppColors.warning,
                    label: 'Verificación en proceso',
                    active: true,
                  ),
                  const Gap(12),
                  _PendingStep(
                    icon: Icons.verified_outlined,
                    color: AppColors.textSecondary,
                    label: 'Cuenta aprobada',
                  ),
                ],
              ),
            ),
            const Gap(24),
            if (profileIncomplete)
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.editProfile),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Completar mi perfil'),
              ),
            const Gap(12),
            TextButton(
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) context.go(AppRoutes.welcome);
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapNotifierProvider);
    final emergencyState = ref.watch(emergencyNotifierProvider);
    final user = ref.watch(authNotifierProvider).value;
    final isAvailable = _isAvailable ?? user?.isAvailable ?? false;

    // ── Pending approval gate ─────────────────────────────────────────────
    if (user?.isApproved != true) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('AutoResQ Técnico'),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: _buildPendingBody(context, user?.specialty),
      );
    }

    // ── Approved: dashboard normal ────────────────────────────────────────
    final lat = mapState.currentLocation?.lat ?? AppConstants.defaultLat;
    final lng = mapState.currentLocation?.lng ?? AppConstants.defaultLng;

    final markers = <MapMarker>[
      technicianMarker(lat, lng, name: 'Tú'),
      ...emergencyState.emergencies.map(
        (e) => emergencyMarker(
          e.lat ?? AppConstants.defaultLat,
          e.lng ?? AppConstants.defaultLng,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.name ?? 'Técnico'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: _onNavTap,
        isTechnician: true,
      ),
      body: Column(
        children: [
          _buildProfileCard(
            specialty: user?.specialty ?? 'Sin especialidad',
            isApproved: user?.isApproved ?? false,
            isAvailable: isAvailable,
            rating: user?.rating ?? 0.0,
            totalServices: user?.totalServices ?? 0,
          ),
          Expanded(
            child: AppMapWidget(
              lat: lat,
              lng: lng,
              zoom: 13.5,
              controller: _mapController,
              markers: markers,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _PendingStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool active;

  const _PendingStep({
    required this.icon,
    required this.color,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const Gap(12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.onSurface : AppColors.textSecondary,
            ),
          ),
        ),
        if (active)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.warning.withOpacity(0.7),
            ),
          ),
      ],
    );
  }
}
