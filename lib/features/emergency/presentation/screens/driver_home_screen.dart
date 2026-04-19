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
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../map/presentation/providers/map_provider.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
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
        break; // Already here
      case 1:
        context.push(AppRoutes.emergencyHistory);
      case 2:
        // Chat list - for now go to history
        context.push(AppRoutes.emergencyHistory);
      case 3:
        context.push(AppRoutes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapNotifierProvider);
    final user = ref.watch(authNotifierProvider).value;

    final lat = mapState.currentLocation?.lat ?? AppConstants.defaultLat;
    final lng = mapState.currentLocation?.lng ?? AppConstants.defaultLng;
    final address = mapState.currentLocation?.address ?? 'Riobamba, Ecuador';

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBody: true,
      body: Stack(
        children: [
          // ─── Glass App Bar ────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 64 + MediaQuery.of(context).padding.top,
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
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
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.menu, color: AppColors.secondary),
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
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.profile),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.1),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Content ─────────────────────────────────────────────────
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
                            const Icon(Icons.location_on, size: 16, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Text(
                              mapState.isLoading ? 'Obteniendo ubicación...' : address,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Map
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 400,
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
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
                                    Marker(
                                      point: LatLng(lat, lng),
                                      width: 48,
                                      height: 48,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withOpacity(0.3),
                                              blurRadius: 12,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 24),
                                      ),
                                    ),
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
                                  _mapControlButton(
                                    Icons.my_location,
                                    () {
                                      ref.read(mapNotifierProvider.notifier).getCurrentLocation();
                                      if (mapState.currentLocation != null) {
                                        _mapController.move(LatLng(lat, lng), 14.5);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _mapControlButton(Icons.layers, () {}),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Services grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      children: [
                        // Header card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.onSurface.withOpacity(0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Servicios Cercanos',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '3 técnicos disponibles ahora',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(Icons.explore, color: AppColors.tertiary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Service cards
                        Row(
                          children: [
                            Expanded(
                              child: _serviceCard(Icons.tire_repair, 'Vulcanizadora', '400m'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _serviceCard(Icons.local_gas_station, 'Combustible', '1.2km'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── FAB ─────────────────────────────────────────────────────
          Positioned(
            bottom: 80 + MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.createEmergency),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

          // ─── Bottom Nav ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNavBar(
              currentIndex: _navIndex,
              onTap: _onNavTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapControlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
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

  Widget _serviceCard(IconData icon, String label, String distance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.03),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$distance',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
