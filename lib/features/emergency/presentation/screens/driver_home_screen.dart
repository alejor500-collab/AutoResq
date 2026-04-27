import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../map/presentation/providers/nearby_services_provider.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mapController = MapController();
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapNotifierProvider.notifier).getCurrentLocation();
    });
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        context.push(AppRoutes.emergencyHistory);
      case 2:
        context.push(AppRoutes.emergencyHistory);
      case 3:
        context.push(AppRoutes.profile);
    }
  }

  /// Animates the map to the given [lat]/[lng] with zoom 17.
  void _flyTo(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 17);
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapNotifierProvider);
    final user = ref.watch(authNotifierProvider).value;

    final lat = mapState.currentLocation?.lat ?? AppConstants.defaultLat;
    final lng = mapState.currentLocation?.lng ?? AppConstants.defaultLng;
    final address =
        mapState.currentLocation?.address ?? 'Riobamba, Ecuador';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      extendBody: true,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // ─── Content ────────────────────────────────────────────────────
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 64 + MediaQuery.of(context).padding.top,
                bottom: 160,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero greeting
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BIENVENIDO DE VUELTA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hola, ${user?.name.split(' ').first ?? 'Conductor'}',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                mapState.isLoading
                                    ? 'Obteniendo ubicación...'
                                    : address,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Map (with service markers)
                  _MapSection(
                    lat: lat,
                    lng: lng,
                    mapController: _mapController,
                    mapState: mapState,
                    onRecenter: () {
                      ref
                          .read(mapNotifierProvider.notifier)
                          .getCurrentLocation();
                      _mapController.move(LatLng(lat, lng), 14.5);
                    },
                  ),

                  const SizedBox(height: 8),

                  // Nearby Services
                  _buildNearbyServices(lat, lng),
                ],
              ),
            ),
          ),

          // ─── FAB ──────────────────────────────────────────────────────
          Positioned(
            bottom: 80 + MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.createEmergency),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.report_problem, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'REPORTAR EMERGENCIA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Bottom Nav ────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNavBar(
              currentIndex: _navIndex,
              onTap: _onNavTap,
            ),
          ),

          // ─── Glass App Bar (last = on top) ─────────────────────────────
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
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            splashColor: AppColors.primary.withOpacity(0.08),
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
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashColor: AppColors.primary.withOpacity(0.08),
                            onTap: () => context.push(AppRoutes.profile),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.15),
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

  // ─── Nearby Services section ─────────────────────────────────────────────
  Widget _buildNearbyServices(double lat, double lng) {
    final nearbyAsync = ref.watch(nearbyServicesProvider((lat, lng)));
    final selectedCat = ref.watch(selectedCategoryProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  'Servicios Cercanos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                nearbyAsync.when(
                  data: (s) {
                    final filtered = selectedCat == null
                        ? s
                        : s.where((x) => x.category == selectedCat).toList();
                    return Text(
                      '${filtered.length} encontrados',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.secondary),
                    );
                  },
                  loading: () => const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary)),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Category filter chips ────────────────────────────────────
          nearbyAsync.when(
            data: (services) {
              // Only show categories that have at least one service
              final available = ServiceCategory.values
                  .where((c) => services.any((s) => s.category == c))
                  .toList();
              if (available.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: available.length + 1, // +1 for "Todos"
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final isAll = selectedCat == null;
                      return _CategoryChip(
                        label: 'Todos',
                        icon: Icons.apps_rounded,
                        color: AppColors.primary,
                        selected: isAll,
                        onTap: () => ref
                            .read(selectedCategoryProvider.notifier)
                            .state = null,
                      );
                    }
                    final cat = available[i - 1];
                    return _CategoryChip(
                      label: cat.label,
                      icon: cat.icon,
                      color: cat.color,
                      selected: selectedCat == cat,
                      onTap: () => ref
                          .read(selectedCategoryProvider.notifier)
                          .state = selectedCat == cat ? null : cat,
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // ── Cards ────────────────────────────────────────────────────
          nearbyAsync.when(
            loading: () => SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => Container(
                  width: 148,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (services) {
              final filtered = selectedCat == null
                  ? services
                  : services
                      .where((s) => s.category == selectedCat)
                      .toList();
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Sin servicios cercanos en 5km',
                      style:
                          TextStyle(color: AppColors.secondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _NearbyServiceCard(
                    service: filtered[i],
                    onTap: () => _flyTo(filtered[i].lat, filtered[i].lng),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Map section widget ────────────────────────────────────────────────────────
class _MapSection extends ConsumerWidget {
  final double lat;
  final double lng;
  final MapController mapController;
  final MapState mapState;
  final VoidCallback onRecenter;

  const _MapSection({
    required this.lat,
    required this.lng,
    required this.mapController,
    required this.mapState,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(nearbyServicesProvider((lat, lng)));
    final selectedCat = ref.watch(selectedCategoryProvider);

    // Build service markers from loaded data
    final serviceMarkers = nearbyAsync.maybeWhen(
      data: (services) {
        final visible = selectedCat == null
            ? services
            : services.where((s) => s.category == selectedCat).toList();
        return visible
            .map(
              (s) => Marker(
                point: LatLng(s.lat, s.lng),
                width: 38,
                height: 38,
                child: _ServiceMapPin(color: s.color, icon: s.icon),
              ),
            )
            .toList();
      },
      orElse: () => <Marker>[],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 380,
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 14.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConstants.osmTileUrl,
                    userAgentPackageName: 'com.autoresq.app',
                  ),
                  MarkerLayer(
                    markers: [
                      // User position marker
                      Marker(
                        point: LatLng(lat, lng),
                        width: 52,
                        height: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.35),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_pin_circle,
                              color: Colors.white, size: 26),
                        ),
                      ),
                      // Service markers
                      ...serviceMarkers,
                    ],
                  ),
                ],
              ),
              // Map controls
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  children: [
                    _MapControlButton(Icons.my_location, onRecenter),
                    const SizedBox(height: 8),
                    _MapControlButton(Icons.layers, () {}),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceMapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _ServiceMapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapControlButton(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withOpacity(0.1),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.onSurface, size: 22),
      ),
    );
  }
}

// ─── Category Chip ─────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.3),
            width: selected ? 0 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Service Card ──────────────────────────────────────────────────────────────
class _NearbyServiceCard extends StatelessWidget {
  final NearbyService service;
  final VoidCallback onTap;

  const _NearbyServiceCard({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: service.color.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: service.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child:
                      Icon(service.icon, color: service.color, size: 18),
                ),
                const Spacer(),
                // Category badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: service.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    service.typeLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: service.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              service.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                height: 1.3,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.near_me_rounded,
                    size: 11, color: AppColors.secondary),
                const SizedBox(width: 3),
                Text(
                  service.distanceLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 14, color: service.color.withOpacity(0.6)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
