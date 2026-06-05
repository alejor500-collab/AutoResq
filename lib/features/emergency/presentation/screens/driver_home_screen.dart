import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/role_provider.dart';
import '../../../../shared/widgets/animated_pressable.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/in_app_message_notice.dart';
import '../../../../shared/widgets/notification_center_sheet.dart';
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
  final _scrollController = ScrollController();
  int _navIndex = 1;
  ProviderSubscription<AsyncValue<int>>? _unreadChatSubscription;
  int _lastUnreadChatCount = 0;
  bool _activeWarningShown = false;
  bool _pendingRatingWarningShown = false;

  @override
  void initState() {
    super.initState();
    ref.read(activeRoleProvider.notifier).switchTo(AppConstants.roleDriver);
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
    _scrollController.dispose();
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

  Future<void> _openNotifications() async {
    await showNotificationCenterSheet(
      context: context,
      ref: ref,
      onNotificationTap: (notification) async {
        if (!mounted) return;
        final referenceId = notification.referenceId;
        if (notification.type == 'nuevo_mensaje' &&
            referenceId?.isNotEmpty == true) {
          context.push(AppRoutes.driverChat, extra: referenceId);
          return;
        }
        if (referenceId?.isNotEmpty == true) {
          context.push(AppRoutes.emergencyStatus, extra: referenceId);
        }
      },
    );
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

  Future<void> _onNavTap(
    int index, {
    required double lat,
    required double lng,
  }) async {
    switch (index) {
      case 0:
        setState(() => _navIndex = 0);
        context.push(AppRoutes.emergencyHistory);
        return;
      case 1:
        if (mounted) setState(() => _navIndex = 1);
        if (_scrollController.hasClients) {
          await _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
        return;
      case 2:
        if (mounted) setState(() => _navIndex = 2);
        await _openNearbyServicesSheet(lat: lat, lng: lng);
        if (mounted) setState(() => _navIndex = 1);
        return;
      case 3:
        setState(() => _navIndex = 3);
        context.push(AppRoutes.profile);
        return;
    }
  }

  Future<void> _openNearbyServicesSheet({
    required double lat,
    required double lng,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final nearbyAsync = ref.watch(nearbyServicesProvider((lat, lng)));
          final selectedCategory = ref.watch(selectedCategoryProvider);

          return DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.52,
            maxChildSize: 0.94,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F6F3),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 58,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D0D0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Servicios cercanos',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF171717),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Explora los puntos disponibles cerca de tu ubicación.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6E6E6E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        children: [
                          _ServiceFilterChip(
                            label: 'Todos',
                            selected: selectedCategory == null,
                            onTap: () => ref
                                .read(selectedCategoryProvider.notifier)
                                .state = null,
                          ),
                          const SizedBox(width: 10),
                          ...ServiceCategory.values.map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _ServiceFilterChip(
                                label: category.label,
                                icon: category.icon,
                                color: category.color,
                                selected: selectedCategory == category,
                                onTap: () => ref
                                    .read(selectedCategoryProvider.notifier)
                                    .state = category,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: nearbyAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                        error: (_, __) => const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'No pudimos cargar los servicios cercanos en este momento.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6E6E6E),
                              ),
                            ),
                          ),
                        ),
                        data: (services) {
                          final filtered = selectedCategory == null
                              ? services
                              : services
                                  .where(
                                    (service) =>
                                        service.category == selectedCategory,
                                  )
                                  .toList();
                          if (filtered.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'No hay servicios cercanos para ese filtro dentro del radio disponible.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6E6E6E),
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            itemBuilder: (context, index) {
                              final service = filtered[index];
                              return _NearbyServiceListTile(
                                service: service,
                                onTap: () {
                                  Navigator.pop(context);
                                  _flyTo(service.lat, service.lng);
                                },
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemCount: filtered.length,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

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
    final address = mapState.currentLocation?.address ??
        mapState.error ??
        'Ubicación no disponible';
    final screenSize = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;
    final firstName = user?.name.split(' ').first ?? 'Conductor';
    final isCompact = screenSize.width < 360;
    final isWide = screenSize.width >= 900;

    Future<void> recenterMap() async {
      await ref.read(mapNotifierProvider.notifier).getCurrentLocation();
      final location = ref.read(mapNotifierProvider).currentLocation;
      _mapController.move(
        LatLng(location?.lat ?? lat, location?.lng ?? lng),
        14.5,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F4F2),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Container(
            color: Colors.white.withValues(alpha: 0.96),
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 24,
              topInset + (isCompact ? 10 : 18),
              isCompact ? 16 : 24,
              isCompact ? 12 : 18,
            ),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedPressable(
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: isCompact ? 34 : 42,
                        height: isCompact ? 52 : 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F1EA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE8DED3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.menu_rounded,
                              size: 18,
                              color: Color(0xFF6A4636),
                            ),
                            SizedBox(height: 4),
                            Icon(
                              Icons.drag_handle_rounded,
                              size: 16,
                              color: Color(0xFFB08974),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: isCompact ? 8 : 10),
                    Container(
                      width: isCompact ? 44 : 58,
                      height: isCompact ? 44 : 58,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: UserAvatar(
                        imageUrl: user?.avatarUrl,
                        name: user?.name ?? 'U',
                        radius: isCompact ? 18 : 24,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: isCompact ? 12 : 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BIENVENIDO',
                        style: TextStyle(
                          fontSize: isCompact ? 10 : 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: isCompact ? 1 : 1.5,
                          color: const Color(0xFF6A4636),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hola, $firstName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 22 : 29,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF171717),
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              mapState.isLoading
                                  ? 'Obteniendo ubicaciÃ³n...'
                                  : address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 10 : 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6E6E6E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: isCompact ? 44 : 58,
                  height: isCompact ? 44 : 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ChatNotificationBell(
                    onTap: _openNotifications,
                    iconColor: const Color(0xFF171717),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isWide
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 188),
                          child: _MapSection(
                            lat: lat,
                            lng: lng,
                            mapController: _mapController,
                            mapState: mapState,
                            onRecenter: recenterMap,
                            onEditLocation: _editLocation,
                            onServiceTap: _flyTo,
                            fillHeight: true,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 16,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: _DriverBottomSheet(
                          address: mapState.isLoading
                              ? 'Obteniendo ubicaciÃ³n...'
                              : address,
                          onEmergencyTap: _openCreateEmergency,
                          nearestCard: _buildNearestServiceCard(lat, lng),
                          navBar: _DriverBottomNav(
                            currentIndex: _navIndex,
                            onTap: (index) => _onNavTap(
                              index,
                              lat: lat,
                              lng: lng,
                            ),
                          ),
                              dense: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: (screenSize.height * 0.24).clamp(160.0, 220.0),
                    ),
                    child: _MapSection(
                      lat: lat,
                      lng: lng,
                      mapController: _mapController,
                      mapState: mapState,
                      onRecenter: recenterMap,
                      onEditLocation: _editLocation,
                      onServiceTap: _flyTo,
                      fillHeight: true,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8 + MediaQuery.of(context).padding.bottom,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _DriverBottomSheet(
                    address: mapState.isLoading
                        ? 'Obteniendo ubicación...'
                        : address,
                    onEmergencyTap: _openCreateEmergency,
                    nearestCard: _buildNearestServiceCard(lat, lng),
                    navBar: _DriverBottomNav(
                      currentIndex: _navIndex,
                      onTap: (index) => _onNavTap(
                        index,
                        lat: lat,
                        lng: lng,
                      ),
                    ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearestServiceCard(double lat, double lng) {
    final nearbyAsync = ref.watch(nearbyServicesProvider((lat, lng)));
    final selectedCat = ref.watch(selectedCategoryProvider);

    return nearbyAsync.when(
      loading: () => const SizedBox(
        height: 102,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, __) => const SizedBox(
        height: 76,
        child: Center(
          child: Text(
            'No se encontraron servicios.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF7A7A7A),
            ),
          ),
        ),
      ),
      data: (services) {
        final filtered = selectedCat == null
            ? services
            : services.where((s) => s.category == selectedCat).toList();
        if (filtered.isEmpty) {
          return const SizedBox(
            height: 76,
            child: Center(
              child: Text(
                'Sin servicios cercanos en 5km.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A7A7A),
                ),
              ),
            ),
          );
        }
        final nearest = filtered.first;
        return _NearestServiceCard(
          service: nearest,
          onTap: () => _flyTo(nearest.lat, nearest.lng),
        );
      },
    );
  }

}

class _MapSection extends ConsumerWidget {
  final double lat;
  final double lng;
  final MapController mapController;
  final MapState mapState;
  final Future<void> Function() onRecenter;
  final Future<void> Function() onEditLocation;
  final void Function(double lat, double lng) onServiceTap;
  final bool fillHeight;

  const _MapSection({
    required this.lat,
    required this.lng,
    required this.mapController,
    required this.mapState,
    required this.onRecenter,
    required this.onEditLocation,
    required this.onServiceTap,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(nearbyServicesProvider((lat, lng)));
    final selectedCat = ref.watch(selectedCategoryProvider);
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 360;
    final isWide = screenSize.width >= 900;

    final serviceMarkers = nearbyAsync.maybeWhen(
      data: (services) {
        final visible = selectedCat == null
            ? services
            : services.where((s) => s.category == selectedCat).toList();
        return visible
            .map(
              (s) => Marker(
                point: LatLng(s.lat, s.lng),
                width: 42,
                height: 42,
                child: _ServiceMapPin(color: s.color, icon: s.icon),
              ),
            )
            .toList();
      },
      orElse: () => <Marker>[],
    );

    final quickActions = nearbyAsync.maybeWhen(
      data: (services) {
        final available = ServiceCategory.values
            .where((c) => services.any((s) => s.category == c))
            .take(4)
            .toList();
        return available.isEmpty
            ? <ServiceCategory>[
                ServiceCategory.fuel,
                ServiceCategory.charging,
                ServiceCategory.carRepair,
                ServiceCategory.tires,
              ]
            : available;
      },
      orElse: () => <ServiceCategory>[
        ServiceCategory.fuel,
        ServiceCategory.charging,
        ServiceCategory.carRepair,
        ServiceCategory.tires,
      ],
    );

    final mapStack = Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
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
                    Marker(
                      point: LatLng(lat, lng),
                      width: 56,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.30),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    ...serviceMarkers,
                  ],
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: isWide ? 0.10 : 0.24),
            ),
          ),
          Positioned(
            left: isWide ? 24 : (isCompact ? 16 : 24),
            top: isWide ? 76 : (isCompact ? 42 : 76),
            child: Column(
              children: quickActions
                  .map(
                    (category) => Padding(
                      padding: EdgeInsets.only(
                        bottom: isWide ? 14 : (isCompact ? 18 : 28),
                      ),
                      child: _QuickActionButton(
                        icon: category.icon,
                        label: category.label,
                        selected: selectedCat == category,
                        onTap: () {
                          final next = selectedCat == category ? null : category;
                          ref.read(selectedCategoryProvider.notifier).state = next;
                          final list = nearbyAsync.valueOrNull ?? <NearbyService>[];
                          final target = list.cast<NearbyService?>().firstWhere(
                                (s) => s?.category == category,
                                orElse: () => null,
                              );
                          if (target != null) {
                            onServiceTap(target.lat, target.lng);
                          }
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Positioned(
            right: isWide ? 24 : (isCompact ? 14 : 24),
            bottom: isWide ? 208 : 18,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.my_location_rounded,
                  onTap: onRecenter,
                ),
                SizedBox(height: isWide ? 10 : (isCompact ? 12 : 18)),
                _MapControlButton(
                  icon: Icons.edit_location_alt_rounded,
                  onTap: onEditLocation,
                ),
              ],
            ),
          ),
        ],
      );

    if (fillHeight) return mapStack;

    return SizedBox(
      height: (screenSize.height * (isCompact ? 0.54 : 0.58))
          .clamp(330.0, 520.0),
      child: mapStack,
    );
  }
}

class _DriverBottomSheet extends StatelessWidget {
  final String address;
  final VoidCallback onEmergencyTap;
  final Widget nearestCard;
  final Widget navBar;
  final bool dense;

  const _DriverBottomSheet({
    required this.address,
    required this.onEmergencyTap,
    required this.nearestCard,
    required this.navBar,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = dense || width < 520;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 10 : 16,
        isCompact ? 6 : 10,
        isCompact ? 10 : 16,
        isCompact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(isCompact ? 24 : 34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? 44 : 72,
            height: isCompact ? 5 : 8,
            decoration: BoxDecoration(
              color: const Color(0xFFD6D6D6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          SizedBox(height: isCompact ? 8 : 14),
          AnimatedPressable(
            onTap: onEmergencyTap,
            borderRadius: BorderRadius.circular(isCompact ? 20 : 30),
            pressedScale: 0.97,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 14 : 20,
                vertical: isCompact ? 12 : 18,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEB1C1C),
                borderRadius: BorderRadius.circular(isCompact ? 20 : 30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEB1C1C).withValues(alpha: 0.22),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: isCompact ? 40 : 52,
                    height: isCompact ? 40 : 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(
                      Icons.sos_rounded,
                      color: Colors.white,
                      size: isCompact ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: isCompact ? 10 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Necesito ayuda',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: isCompact ? 10 : 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: isCompact ? 1 : 3),
                        Text(
                          'Reportar emergencia',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 14 : 18,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isCompact ? 6 : 10),
                  Container(
                    width: isCompact ? 34 : 42,
                    height: isCompact ? 34 : 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: const Color(0xFFEB1C1C),
                      size: isCompact ? 20 : 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isCompact ? 8 : 12),
          nearestCard,
          SizedBox(height: isCompact ? 8 : 12),
          navBar,
        ],
      ),
    );
  }
}

class _NearestServiceCard extends StatelessWidget {
  final NearbyService service;
  final VoidCallback onTap;

  const _NearestServiceCard({
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 520;

    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isCompact ? 18 : 26),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 10 : 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(isCompact ? 18 : 26),
          border: Border.all(color: const Color(0xFFE3E3E3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isCompact ? 44 : 56,
              height: isCompact ? 44 : 56,
              decoration: BoxDecoration(
                color: const Color(0xFFD8E6F3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                service.icon,
                color: AppColors.primary,
                size: isCompact ? 22 : 26,
              ),
            ),
            SizedBox(width: isCompact ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Más cercano',
                    style: TextStyle(
                      fontSize: isCompact ? 10 : 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5B4137),
                    ),
                  ),
                  SizedBox(height: isCompact ? 1 : 4),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: isCompact ? 13 : 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF171717),
                      ),
                      children: [
                        TextSpan(text: service.name),
                        TextSpan(
                          text: ' (${service.distanceLabel})',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: isCompact ? 13 : 16,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: isCompact ? 6 : 10),
            Container(
              width: isCompact ? 38 : 46,
              height: isCompact ? 38 : 46,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF171717),
                size: isCompact ? 22 : 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : (color ?? AppColors.primary);
    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? (color ?? AppColors.primary) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? (color ?? AppColors.primary)
                : const Color(0xFFE5DED6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyServiceListTile extends StatelessWidget {
  final NearbyService service;
  final VoidCallback onTap;

  const _NearbyServiceListTile({
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE8E1D8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: service.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(service.icon, color: service.color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.typeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: service.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    service.distanceLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: service.color,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF171717),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _DriverBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 520;
    const items = [
      _NavItem('History', Icons.history_rounded, Icons.history_rounded),
      _NavItem('Home', Icons.home_outlined, Icons.home_rounded),
      _NavItem('Servicios', Icons.storefront_outlined, Icons.storefront_rounded),
      _NavItem('Profile', Icons.person_outline_rounded,
          Icons.person_rounded),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 8,
        vertical: isCompact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(isCompact ? 24 : 34),
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isActive = index == currentIndex;
          return Expanded(
            child: AnimatedPressable(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(vertical: isCompact ? 5 : 8),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFD90F16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(isCompact ? 20 : 28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? item.activeIcon : item.icon,
                      size: isCompact ? 18 : 24,
                      color: isActive ? Colors.white : AppColors.primary,
                    ),
                    SizedBox(height: isCompact ? 2 : 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: isCompact ? 8 : 11,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem(this.label, this.icon, this.activeIcon);
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 360;
    final isWide = MediaQuery.of(context).size.width >= 900;
    final size = isWide ? 54.0 : (isCompact ? 50.0 : 58.0);

    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.14),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.10),
              blurRadius: selected ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.primary,
              size: isWide ? 21 : 23,
            ),
            const SizedBox(height: 3),
            Text(
              label.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                height: 1,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceMapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _ServiceMapPin({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final Future<void> Function() onTap;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 360;
    final isWide = MediaQuery.of(context).size.width >= 900;
    final size = isWide ? 44.0 : (isCompact ? 42.0 : 48.0);

    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: isWide ? 21 : 23),
      ),
    );
  }
}
