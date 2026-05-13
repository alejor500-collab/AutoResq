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
import '../../../../shared/widgets/animated_pressable.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/in_app_message_notice.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/widgets/chat_notification_bell.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../map/presentation/providers/nearby_services_provider.dart';
import '../../../map/presentation/widgets/location_picker_sheet.dart';
import '../../domain/entities/emergency_entity.dart';
import '../providers/emergency_provider.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mapController = MapController();
  final int _navIndex = 0;
  ProviderSubscription<AsyncValue<int>>? _unreadChatSubscription;
  int _lastUnreadChatCount = 0;
  bool _activeWarningShown = false;
  bool _pendingRatingWarningShown = false;

  @override
  void initState() {
    super.initState();
    _unreadChatSubscription = ref.listenManual<AsyncValue<int>>(
      unreadChatCountProvider,
      _handleUnreadChatCount,
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapNotifierProvider.notifier).getCurrentLocation();
      _restoreActiveEmergency();
    });
  }

  @override
  void dispose() {
    _unreadChatSubscription?.close();
    super.dispose();
  }

  void _handleUnreadChatCount(
    AsyncValue<int>? previous,
    AsyncValue<int> next,
  ) {
    final count = next.valueOrNull ?? _lastUnreadChatCount;
    final previousCount = previous?.valueOrNull ?? _lastUnreadChatCount;
    final isInitialValue = previous == null && _lastUnreadChatCount == 0;
    _lastUnreadChatCount = count;

    if (isInitialValue || count <= previousCount || !mounted) return;
    showInAppMessageNotice(
      context,
      message: 'Nuevo mensaje',
      detail: 'Toca para abrir el chat',
      onTap: _openLatestUnreadChat,
    );
  }

  Future<void> _openLatestUnreadChat() async {
    final active = await ref
        .read(emergencyNotifierProvider.notifier)
        .loadActiveDriverEmergency();
    if (!mounted) return;
    if (active?.asignacionId?.isNotEmpty == true) {
      context.push(AppRoutes.driverChat, extra: active!.id);
      return;
    }
    context.push(AppRoutes.driverChatHistory);
  }

  Future<void> _restoreActiveEmergency() async {
    final active = await ref
        .read(emergencyNotifierProvider.notifier)
        .loadActiveDriverEmergency();
    if (!mounted) return;
    if (active != null) {
      _showActiveEmergencyDialog(active, fromStartup: true);
      return;
    }

    Map<String, dynamic>? pending;
    try {
      pending = await ref
          .read(emergencyNotifierProvider.notifier)
          .getPendingRating('driver');
    } catch (_) {
      pending = null;
    }
    if (!mounted || pending == null) return;
    _showPendingRatingDialog(pending, fromStartup: true);
  }

  void _showActiveEmergencyDialog(
    Emergency active, {
    bool fromStartup = false,
  }) {
    if (fromStartup && _activeWarningShown) return;
    _activeWarningShown = true;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Emergencia en curso'),
        content: const Text(
          'Ya tienes una emergencia activa. Para registrar una nueva solicitud primero debes cancelar o finalizar el servicio actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push(AppRoutes.emergencyStatus, extra: active.id);
            },
            child: const Text('Ver servicio'),
          ),
        ],
      ),
    );
  }

  void _showPendingRatingDialog(
    Map<String, dynamic> pendingRating, {
    bool fromStartup = false,
  }) {
    if (fromStartup && _pendingRatingWarningShown) return;
    _pendingRatingWarningShown = true;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Calificacion pendiente'),
        content: const Text(
          'Tu ultimo servicio ya finalizo. Califica al tecnico para cerrar el flujo y poder solicitar una nueva emergencia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                AppRoutes.rateService,
                extra: {
                  'emergencyId':
                      pendingRating['emergency_id']?.toString() ?? '',
                  'technicianId':
                      pendingRating['rated_user_id']?.toString() ?? '',
                  'technicianName':
                      pendingRating['rated_user_name']?.toString() ??
                          'Tecnico',
                },
              );
            },
            child: const Text('Calificar ahora'),
          ),
        ],
      ),
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        context.push(AppRoutes.emergencyHistory);
      case 2:
        context.push(AppRoutes.driverChatHistory);
      case 3:
        context.push(AppRoutes.profile);
    }
  }

  /// Animates the map to the given [lat]/[lng] with zoom 17.
  void _flyTo(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 17);
  }

  Future<void> _editLocation() async {
    final selected = await showLocationPickerSheet(
      context,
      title: 'Editar ubicacion de servicio',
      initialLocation: ref.read(mapNotifierProvider).currentLocation,
    );
    if (selected == null || !mounted) return;
    ref.read(mapNotifierProvider.notifier).setLocation(selected);
    _mapController.move(LatLng(selected.lat, selected.lng), 15);
  }

  Future<void> _openCreateEmergency() async {
    Map<String, dynamic>? pending;
    try {
      pending = await ref
          .read(emergencyNotifierProvider.notifier)
          .getPendingRating('driver');
    } catch (_) {
      pending = null;
    }
    if (!mounted) return;
    final active = await ref
        .read(emergencyNotifierProvider.notifier)
        .loadActiveDriverEmergency();
    if (!mounted) return;
    if (active != null) {
      _showActiveEmergencyDialog(active);
      return;
    }
    if (pending != null) {
      _showPendingRatingDialog(pending);
      return;
    }
    context.push(AppRoutes.createEmergency);
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapNotifierProvider);
    final user = ref.watch(authNotifierProvider).value;

    final lat = mapState.currentLocation?.lat ?? AppConstants.defaultLat;
    final lng = mapState.currentLocation?.lng ?? AppConstants.defaultLng;
    final address =
        mapState.error ?? mapState.currentLocation?.address ?? 'Ecuador';

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
                  // Driver hero
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryContainer,
                            AppColors.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BIENVENIDO DE VUELTA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hola, ${user?.name.split(' ').first ?? 'Conductor'}',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.84)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  mapState.isLoading
                                      ? 'Obteniendo ubicación...'
                                      : address,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.84),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Editar ubicacion',
                                visualDensity: VisualDensity.compact,
                                onPressed: _editLocation,
                                icon: const Icon(
                                  Icons.edit_location_alt_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Map (with service markers)
                  _MapSection(
                    lat: lat,
                    lng: lng,
                    mapController: _mapController,
                    mapState: mapState,
                    onRecenter: () async {
                      await ref
                          .read(mapNotifierProvider.notifier)
                          .getCurrentLocation();
                      final location =
                          ref.read(mapNotifierProvider).currentLocation;
                      _mapController.move(
                        LatLng(location?.lat ?? lat, location?.lng ?? lng),
                        14.5,
                      );
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
              child: AnimatedPressable(
                onTap: _openCreateEmergency,
                borderRadius: BorderRadius.circular(9999),
                pressedScale: 0.94,
                hoverScale: 1.02,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                    color: Colors.white.withValues(alpha: 0.82),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
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
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            splashColor: AppColors.primary.withValues(alpha: 0.08),
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
                        Text(
                          'AutoResQ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        ChatNotificationBell(
                          onTap: _openLatestUnreadChat,
                          iconColor: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashColor: AppColors.primary.withValues(alpha: 0.08),
                            onTap: () => context.push(AppRoutes.profile),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.15),
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
              height: 150,
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
                  : services.where((s) => s.category == selectedCat).toList();
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
                height: 150,
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
  final Future<void> Function() onRecenter;

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
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
                top: 14,
                left: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.near_me_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Servicios en ruta',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  children: [
                    _MapControlButton(Icons.my_location, () {
                      onRecenter();
                    }),
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
            color: color.withValues(alpha: 0.45),
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
    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      pressedScale: 0.92,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.1),
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
    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      pressedScale: 0.94,
      hoverScale: 1.025,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.0)
                : color.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? color.withValues(alpha: 0.26)
                  : AppColors.onSurface.withValues(alpha: 0.04),
              blurRadius: selected ? 14 : 8,
              offset: Offset(0, selected ? 5 : 2),
            ),
          ],
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
                fontWeight: FontWeight.w800,
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
    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      pressedScale: 0.96,
      hoverScale: 1.025,
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: service.color.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: service.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(service.icon, color: service.color, size: 18),
                ),
                const Spacer(),
                // Category badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: service.color.withValues(alpha: 0.08),
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
                const Icon(Icons.near_me_rounded,
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
                    size: 14, color: service.color.withValues(alpha: 0.6)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
