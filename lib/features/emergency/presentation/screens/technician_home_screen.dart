import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/role_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../map/presentation/providers/nearby_services_provider.dart';
import '../../../map/presentation/widgets/map_widget.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';

class TechnicianHomeScreen extends ConsumerStatefulWidget {
  const TechnicianHomeScreen({super.key});

  @override
  ConsumerState<TechnicianHomeScreen> createState() =>
      _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends ConsumerState<TechnicianHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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
    switch (index) {
      case 0:
      case 2:
        setState(() => _navIndex = index);
        break;
      case 1:
        context.push(AppRoutes.emergencyHistory);
        break;
      case 3:
        context.push(AppRoutes.profile);
        break;
    }
  }

  Future<void> _recenterToCurrentLocation() async {
    await ref.read(mapNotifierProvider.notifier).getCurrentLocation();
    final location = ref.read(mapNotifierProvider).currentLocation;
    if (!mounted || location == null) return;
    _mapController.move(LatLng(location.lat, location.lng), 15.5);
  }

  void _refreshEmergencies() {
    ref.read(emergencyNotifierProvider.notifier).loadPendingEmergencies();
  }

  Future<void> _toggleAvailability(bool val) async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    setState(() => _isAvailable = val);
    try {
      final rows = await ref
          .read(supabaseClientProvider)
          .from(AppConstants.tableTecnicos)
          .update({'disponible': val})
          .eq('usuario_id', user.id)
          .select('disponible');
      if (rows.isEmpty) {
        setState(() => _isAvailable = !val);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No se encontró el perfil de técnico')),
          );
        }
        return;
      }
      final persisted =
          (rows.first as Map<String, dynamic>)['disponible'] as bool? ?? val;
      setState(() => _isAvailable = persisted);
      ref.read(technicianAvailableProvider.notifier).state = persisted;
      final updated = user.copyWith(isAvailable: persisted);
      ref.read(authNotifierProvider.notifier).refreshUser(updated);
      ref.read(currentUserProvider.notifier).state = updated;
    } catch (e) {
      debugPrint('[AutoResQ] toggleAvailability ERROR: $e');
      setState(() => _isAvailable = !val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
    required int pendingCount,
  }) {
    final chipColor = isApproved ? AppColors.success : AppColors.warning;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.engineering_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Panel tecnico',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      specialty,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Switch(
                value: isAvailable,
                onChanged: _toggleAvailability,
                activeThumbColor: AppColors.success,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: _TechnicianMetricPill(
                  icon: isApproved
                      ? Icons.verified_rounded
                      : Icons.hourglass_top_rounded,
                  label: isApproved ? 'Verificado' : 'Pendiente',
                  value: isAvailable ? 'Disponible' : 'No disponible',
                  color: chipColor,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _TechnicianMetricPill(
                  icon: Icons.report_problem_outlined,
                  label: 'Solicitudes',
                  value: '$pendingCount activas',
                  color: AppColors.primary,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _TechnicianMetricPill(
                  icon: Icons.star_rounded,
                  label: rating.toStringAsFixed(1),
                  value: '$totalServices servicios',
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapView({
    required double lat,
    required double lng,
    required List<MapMarker> markers,
    required List<Emergency> emergencies,
    required bool isAvailable,
    required bool isLoading,
  }) {
    final preview = emergencies.take(2).toList();

    return Stack(
      children: [
        AppMapWidget(
          lat: lat,
          lng: lng,
          zoom: 13.5,
          controller: _mapController,
          markers: markers,
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: _TechnicianMapPanel(
            count: emergencies.length,
            isAvailable: isAvailable,
            isLoading: isLoading,
            emergencies: preview,
            onRefresh: _refreshEmergencies,
            onTapEmergency: (emergency) {
              _mapController.move(
                LatLng(
                  emergency.lat ?? AppConstants.defaultLat,
                  emergency.lng ?? AppConstants.defaultLng,
                ),
                16,
              );
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapActionButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Localizarme',
                onTap: _recenterToCurrentLocation,
              ),
              const Gap(10),
              _MapActionButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Actualizar emergencias',
                onTap: _refreshEmergencies,
                showProgress: isLoading,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Services tab (SERVICIOS) ──────────────────────────────────────────────

  Widget _buildServicesView(double lat, double lng) {
    final nearbyAsync = ref.watch(nearbyServicesProvider((lat, lng)));
    final selectedCat = ref.watch(selectedCategoryProvider);

    return nearbyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.secondary,
            ),
            const Gap(16),
            const Text(
              'Error al cargar servicios cercanos',
              style: TextStyle(fontSize: 15, color: AppColors.secondary),
            ),
            const Gap(8),
            TextButton(
              onPressed: () =>
                  ref.invalidate(nearbyServicesProvider((lat, lng))),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (services) {
        final availableCategories = ServiceCategory.values
            .where((category) => services.any((s) => s.category == category))
            .toList();
        final filtered = selectedCat == null
            ? services
            : services.where((s) => s.category == selectedCat).toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            Row(
              children: [
                const Text(
                  'Servicios cercanos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} encontrados',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const Gap(12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableCategories.length + 1,
                separatorBuilder: (_, __) => const Gap(8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _ServiceCategoryChip(
                      label: 'Todos',
                      icon: Icons.apps_rounded,
                      color: AppColors.primary,
                      selected: selectedCat == null,
                      onTap: () => ref
                          .read(selectedCategoryProvider.notifier)
                          .state = null,
                    );
                  }
                  final category = availableCategories[i - 1];
                  return _ServiceCategoryChip(
                    label: category.label,
                    icon: category.icon,
                    color: category.color,
                    selected: selectedCat == category,
                    onTap: () => ref
                        .read(selectedCategoryProvider.notifier)
                        .state = selectedCat == category ? null : category,
                  );
                },
              ),
            ),
            const Gap(16),
            if (filtered.isEmpty)
              const _EmptyNearbyServices()
            else
              ...filtered.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TechnicianNearbyServiceCard(
                    service: service,
                    onTap: () {
                      setState(() => _navIndex = 0);
                      _mapController.move(
                        LatLng(service.lat, service.lng),
                        17,
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Pending approval UI ───────────────────────────────────────────────────

  Widget _buildPendingBody(BuildContext context, String? specialty) {
    final profileIncomplete = specialty == null || specialty.trim().isEmpty;

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
                color: AppColors.warning.withValues(alpha: 0.12),
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
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusCard),
              ),
              child: const Column(
                children: [
                  _PendingStep(
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    label: 'Registro completado',
                  ),
                  Gap(12),
                  _PendingStep(
                    icon: Icons.manage_search_outlined,
                    color: AppColors.warning,
                    label: 'Verificación en proceso',
                    active: true,
                  ),
                  Gap(12),
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
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: _onNavTap,
        isTechnician: true,
      ),
      body: Stack(
        children: [
          // ── Content: spacer + profile card + map ──────────────────────
          Column(
            children: [
              SizedBox(height: 64 + MediaQuery.of(context).padding.top),
              _buildProfileCard(
                specialty: user?.specialty ?? 'Sin especialidad',
                isApproved: user?.isApproved ?? false,
                isAvailable: isAvailable,
                rating: user?.rating ?? 0.0,
                totalServices: user?.totalServices ?? 0,
                pendingCount: emergencyState.emergencies.length,
              ),
              Expanded(
                child: _navIndex == 2
                    ? _buildServicesView(lat, lng)
                    : _buildMapView(
                        lat: lat,
                        lng: lng,
                        markers: markers,
                        emergencies: emergencyState.emergencies,
                        isAvailable: isAvailable,
                        isLoading: emergencyState.isLoading,
                      ),
              ),
            ],
          ),

          // ── Glass AppBar (on top) ──────────────────────────────────────
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
                        // Menu
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            splashColor:
                                AppColors.primary.withValues(alpha: 0.08),
                            onTap: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.menu_rounded,
                                  color: AppColors.secondary, size: 24),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'AutoResQ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        // Avatar
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashColor:
                                AppColors.primary.withValues(alpha: 0.08),
                            onTap: () => context.push(AppRoutes.profile),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.15),
                                  width: 2,
                                ),
                              ),
                              child: UserAvatar(
                                imageUrl: user?.avatarUrl,
                                name: user?.name ?? 'U',
                                radius: 18,
                              ),
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
        ],
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

// ── Emergency card for SERVICIOS tab ─────────────────────────────────────────

class _TechnicianMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TechnicianMetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const Gap(7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const Gap(2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
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

class _TechnicianMapPanel extends StatelessWidget {
  final int count;
  final bool isAvailable;
  final bool isLoading;
  final List<Emergency> emergencies;
  final VoidCallback onRefresh;
  final ValueChanged<Emergency> onTapEmergency;

  const _TechnicianMapPanel({
    required this.count,
    required this.isAvailable,
    required this.isLoading,
    required this.emergencies,
    required this.onRefresh,
    required this.onTapEmergency,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
            border: Border.all(
              color: AppColors.onSurface.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mapa operativo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          isAvailable
                              ? '$count solicitudes cerca'
                              : 'Activa disponibilidad para recibir alertas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar emergencias',
                    onPressed: onRefresh,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    color: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (emergencies.isNotEmpty) ...[
                const Gap(12),
                ...emergencies.map(
                  (emergency) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EmergencyPreviewTile(
                      emergency: emergency,
                      onTap: () => onTapEmergency(emergency),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyPreviewTile extends StatelessWidget {
  final Emergency emergency;
  final VoidCallback onTap;

  const _EmergencyPreviewTile({
    required this.emergency,
    required this.onTap,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final label = emergency.clasificacionIa?.isNotEmpty == true
        ? emergency.clasificacionIa!
        : 'Emergencia';

    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          _timeAgo(emergency.fecha),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      emergency.direccion ??
                          emergency.driverName ??
                          emergency.descripcion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(6),
              const Icon(
                Icons.center_focus_strong_rounded,
                color: AppColors.secondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showProgress;

  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        shadowColor: AppColors.primary.withValues(alpha: 0.30),
        child: InkWell(
          onTap: showProgress ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: showProgress
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 23),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmergencyServiceCard extends StatelessWidget {
  final Emergency emergency;

  const _EmergencyServiceCard({required this.emergency});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora mismo';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final label = emergency.clasificacionIa?.isNotEmpty == true
        ? emergency.clasificacionIa!
        : 'Emergencia';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _timeAgo(emergency.fecha),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Gap(8),
            // Driver name
            if (emergency.driverName != null) ...[
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: AppColors.secondary),
                  const Gap(4),
                  Expanded(
                    child: Text(
                      emergency.driverName!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Gap(4),
            ],
            // Description
            Text(
              emergency.descripcion,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurface,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Address
            if (emergency.direccion != null) ...[
              const Gap(6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.secondary),
                  const Gap(4),
                  Expanded(
                    child: Text(
                      emergency.direccion!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _ServiceCategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceCategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : color),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicianNearbyServiceCard extends StatelessWidget {
  final NearbyService service;
  final VoidCallback onTap;

  const _TechnicianNearbyServiceCard({
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
            border: Border.all(color: service.color.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: service.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(service.icon, color: service.color, size: 22),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
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
                      service.typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: service.color,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Text(
                service.distanceLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNearbyServices extends StatelessWidget {
  const _EmptyNearbyServices();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
      ),
      child: const Text(
        'Sin servicios cercanos en 5km',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.secondary),
      ),
    );
  }
}

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
              color: AppColors.warning.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}
