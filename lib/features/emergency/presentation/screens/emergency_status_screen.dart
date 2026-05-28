import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/emergency_match_policy.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../chat/presentation/widgets/chat_notification_bell.dart';
import '../../../../shared/utils/app_responsive.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/notification_center_sheet.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';

class EmergencyStatusScreen extends ConsumerWidget {
  final String emergencyId;

  const EmergencyStatusScreen({super.key, required this.emergencyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(watchEmergencyProvider(emergencyId));

    return stream.when(
      loading: () => const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text(e.toString())),
      ),
      data: (emergency) => _StatusBody(emergency: emergency),
    );
  }
}

Future<void> _callPhone(BuildContext context, String? phone) async {
  final digits = phone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
  if (digits.isEmpty) {
    AppHelpers.showSnackBar(
      context,
      'No hay telefono registrado para llamar',
      isError: true,
    );
    return;
  }
  final uri = Uri(scheme: 'tel', path: digits);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    AppHelpers.showSnackBar(
      context,
      'No se pudo abrir la app de telefono',
      isError: true,
    );
  }
}

double? _snapshotDouble(Emergency emergency, String key) {
  return (emergency.priceSnapshot?[key] as num?)?.toDouble();
}

bool _isTowEmergency(Emergency emergency) {
  return emergency.priceSnapshot?['pricing_type'] == 'distance_based' ||
      emergency.priceSnapshot?['service_code'] == 'tow_service' ||
      emergency.aiEmergencyType == 'tow_service' ||
      emergency.clasificacionIa == 'Grúa / remolque';
}

class _StatusBody extends ConsumerStatefulWidget {
  final Emergency emergency;

  const _StatusBody({required this.emergency});

  @override
  ConsumerState<_StatusBody> createState() => _StatusBodyState();
}

class _StatusBodyState extends ConsumerState<_StatusBody> {
  bool _ratingDialogShown = false;

  Future<void> _openNotifications(Emergency emergency) async {
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
          context.go(AppRoutes.emergencyStatus, extra: referenceId);
        } else if (emergency.asignacionId?.isNotEmpty == true) {
          context.push(AppRoutes.driverChat, extra: emergency.id);
        }
      },
    );
  }

  void _showDriverRatingDialog(Emergency emergency) {
    if (_ratingDialogShown) return;
    _ratingDialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final technicianName = emergency.tecnicoNombre?.trim().isNotEmpty == true
          ? emergency.tecnicoNombre!.trim()
          : 'tu tecnico';
      final technicianId =
          emergency.tecnicoUsuarioId ?? emergency.tecnicoId ?? '';

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Califica tu servicio'),
          content: Text(
            'El servicio finalizo. Califica a $technicianName para cerrar la solicitud y poder pedir una nueva emergencia.',
          ),
          actions: [
            FilledButton(
              onPressed: technicianId.isEmpty
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      context.push(
                        AppRoutes.rateService,
                        extra: {
                          'emergencyId': emergency.id,
                          'technicianId': technicianId,
                          'technicianName': technicianName,
                        },
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Calificar ahora'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _cancelService(BuildContext context, WidgetRef ref) async {
    final emergency = widget.emergency;
    final isPendingSearch =
        emergency.estado == AppConstants.statusPending && !emergency.hasTechnician;
    final cancelMessage = isPendingSearch
        ? 'Se cancelara la busqueda de tecnico. No se generara ningun cargo.'
        : emergency.hasTechnician
            ? 'El servicio ya fue aceptado por un tecnico. Se marcara como cancelado y quedara registrado en tu historial.'
            : 'Se cancelara esta solicitud de emergencia.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Cancelar servicio'),
        content: Text(cancelMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar servicio'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(emergencyNotifierProvider.notifier)
        .updateStatus(emergency.id, AppConstants.statusCancelled);
    if (!context.mounted) return;
    if (ok) {
      ref.read(emergencyNotifierProvider.notifier).clearActiveEmergency();
      AppHelpers.showSnackBar(
        context,
        isPendingSearch ? 'Solicitud cancelada.' : 'Servicio cancelado.',
        isSuccess: true,
      );
      context.go(AppRoutes.driverHome);
      return;
    }

    AppHelpers.showSnackBar(
      context,
      ref.read(emergencyNotifierProvider).error ??
          'No se pudo cancelar el servicio.',
      isError: true,
    );
  }

  Future<void> _acceptOffer(TechnicianOffer offer) async {
    final ok = await ref
        .read(emergencyNotifierProvider.notifier)
        .acceptTechnicianOffer(offer.id, widget.emergency.id);
    if (!mounted) return;
    if (ok) {
      AppHelpers.showSnackBar(
        context,
        '${offer.name} fue asignado a tu servicio.',
        isSuccess: true,
      );
      return;
    }

    AppHelpers.showSnackBar(
      context,
      ref.read(emergencyNotifierProvider).error ??
          'No se pudo elegir este tecnico.',
      isError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final emergency = widget.emergency;
    final emergencyState = ref.watch(emergencyNotifierProvider);
    final offersAsync =
        emergency.estado == AppConstants.statusPending && !emergency.hasTechnician
            ? ref.watch(technicianOffersProvider(emergency.id))
            : const AsyncValue<List<TechnicianOffer>>.data([]);
    final lat = emergency.lat ?? AppConstants.defaultLat;
    final lng = emergency.lng ?? AppConstants.defaultLng;
    final offers = offersAsync.valueOrNull ?? const <TechnicianOffer>[];
    final towDestinationLat = _snapshotDouble(emergency, 'destination_lat');
    final towDestinationLng = _snapshotDouble(emergency, 'destination_lng');
    final hasTowDestination =
        _isTowEmergency(emergency) &&
        towDestinationLat != null &&
        towDestinationLng != null;
    final technicianLocation = emergency.tecnicoId == null
        ? const AsyncValue<TechnicianLiveLocation?>.data(null)
        : ref.watch(technicianLiveLocationProvider(emergency.tecnicoId!));
    final tech = technicianLocation.valueOrNull;
    final routeEstimate = tech == null
        ? null
        : ref.watch(
            technicianRouteEstimateProvider(
              (
                originLat: tech.lat,
                originLng: tech.lng,
                destinationLat: lat,
                destinationLng: lng,
              ),
            ),
          );
    final towRouteEstimate = hasTowDestination
        ? ref.watch(
            technicianRouteEstimateProvider(
              (
                originLat: lat,
                originLng: lng,
                destinationLat: towDestinationLat,
                destinationLng: towDestinationLng,
              ),
            ),
          )
        : null;
    final isCompleted = emergency.estado == AppConstants.statusCompleted ||
        emergency.asignacionEstado == AppConstants.assignFinished;
    if (isCompleted) {
      _showDriverRatingDialog(emergency);
    }
    final horizontal = AppResponsive.horizontalPadding(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.pageBackgroundGradient,
              ),
            ),
          ),
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
                  padding: EdgeInsets.only(top: topInset),
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
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: Row(
                      children: [
                        // Back button
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => context.pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.arrow_back_ios_new,
                                  color: AppColors.onSurface, size: 20),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Estado del servicio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        // Profile avatar → /profile
                        ChatNotificationBell(
                          onTap: () => _openNotifications(emergency),
                          iconColor: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => context.push(AppRoutes.profile),
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.surfaceContainerHigh,
                              child: Icon(Icons.person,
                                  size: 18, color: AppColors.secondary),
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
            top: 64 + topInset,
            bottom: 80 + MediaQuery.of(context).padding.bottom,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
              child: AppResponsiveContent(
                child: AppStaggeredColumn(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // ETA Hero
                  _ETAHero(
                    emergency: emergency,
                    route: routeEstimate?.valueOrNull,
                    hasTechnicianLocation: tech != null,
                    isRouteLoading: routeEstimate?.isLoading ?? false,
                  ),
                  const Gap(24),

                  // Live Map
                  _LiveMap(
                    lat: lat,
                    lng: lng,
                    address: emergency.direccion,
                    technicianLocation: tech,
                    nearbyOffers: offers,
                    towDestination: hasTowDestination
                        ? LatLng(towDestinationLat, towDestinationLng)
                        : null,
                    route: routeEstimate?.valueOrNull,
                    towRoute: towRouteEstimate?.valueOrNull,
                    isTow: _isTowEmergency(emergency),
                  ),
                  const Gap(24),

                  // Technician Card
                  if (emergency.hasTechnician)
                    _TechnicianCard(
                      emergency: emergency,
                      route: routeEstimate?.valueOrNull,
                      onCancel: () => _cancelService(context, ref),
                    )
                  else
                    _OfferSelectionCard(
                      offersAsync: offersAsync,
                      emergencyType:
                          emergency.aiEmergencyType ?? emergency.clasificacionIa,
                      isChoosing: emergencyState.isLoading,
                      onAccept: _acceptOffer,
                      onCancel: () => _cancelService(context, ref),
                    ),
                  const Gap(24),

                  if (isCompleted) ...[
                    _DriverRatingPrompt(emergency: emergency),
                    const Gap(24),
                  ],

                  // Timeline
                  _TimelineStepper(emergency: emergency),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Nav
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNavBar(
              currentIndex: 1,
              onTap: (i) {
                switch (i) {
                  case 0:
                    context.go(AppRoutes.driverHome);
                  case 2:
                    if (emergency.hasTechnician) {
                      context.push(AppRoutes.driverChat, extra: emergency.id);
                    }
                  case 3:
                    context.push(AppRoutes.profile);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ETA Hero ─────────────────────────────────────────────────────────────────

class _DriverRatingPrompt extends StatelessWidget {
  final Emergency emergency;

  const _DriverRatingPrompt({required this.emergency});

  @override
  Widget build(BuildContext context) {
    final technicianName = emergency.tecnicoNombre?.trim().isNotEmpty == true
        ? emergency.tecnicoNombre!.trim()
        : 'tu tecnico';
    final technicianId = emergency.tecnicoUsuarioId ?? emergency.tecnicoId ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const Gap(12),
              const Expanded(
                child: Text(
                  'Servicio finalizado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          Text(
            'Califica a $technicianName para cerrar este servicio y poder solicitar una nueva emergencia.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.secondary,
            ),
          ),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: technicianId.isEmpty
                  ? null
                  : () => context.push(
                        AppRoutes.rateService,
                        extra: {
                          'emergencyId': emergency.id,
                          'technicianId': technicianId,
                          'technicianName': technicianName,
                        },
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              icon: const Icon(Icons.star_rounded, size: 18),
              label: const Text('Calificar servicio'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ETAHero extends StatelessWidget {
  final Emergency emergency;
  final RouteEstimate? route;
  final bool hasTechnicianLocation;
  final bool isRouteLoading;

  const _ETAHero({
    required this.emergency,
    required this.route,
    required this.hasTechnicianLocation,
    required this.isRouteLoading,
  });

  @override
  Widget build(BuildContext context) {
    final (etaText, subtitle) = _getETAInfo();

    return Column(
      children: [
        const Text(
          'TIEMPO ESTIMADO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.secondary,
          ),
        ),
        const Gap(4),
        Text(
          etaText,
          style: TextStyle(
            fontSize: AppResponsive.isCompact(context) ? 40 : 48,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: 0,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  (String, String) _getETAInfo() {
    if (emergency.estado == AppConstants.statusCompleted) {
      return ('Listo', 'Servicio completado');
    }
    switch (emergency.asignacionEstado) {
      case AppConstants.assignAccepted:
        if (!hasTechnicianLocation) {
          return ('...', 'Esperando ubicacion del tecnico');
        }
        if (isRouteLoading || route == null) {
          return ('...', 'Calculando llegada del tecnico');
        }
        final approx = route!.isApproximate ? ' aprox.' : '';
        return (
          '${route!.durationMinutes} min',
          'A ${route!.distanceLabel} de tu ubicacion$approx',
        );
      case AppConstants.assignEnRoute:
        if (!hasTechnicianLocation) {
          return ('...', 'Esperando ubicacion del tecnico');
        }
        if (isRouteLoading || route == null) {
          return ('...', 'Calculando ruta del tecnico');
        }
        final approx = route!.isApproximate ? ' aprox.' : '';
        return (
          '${route!.durationMinutes} min',
          'El tecnico esta a ${route!.distanceLabel}$approx',
        );
      case AppConstants.assignAttending:
        return ('--', 'El tecnico esta atendiendo tu vehiculo');
      case AppConstants.assignFinished:
        return ('Listo', 'Servicio completado');
      default:
        return ('...', 'Buscando tecnico disponible');
    }
  }
}

// ─── Live Map ─────────────────────────────────────────────────────────────────

class _LiveMap extends StatelessWidget {
  final double lat;
  final double lng;
  final String? address;
  final TechnicianLiveLocation? technicianLocation;
  final List<TechnicianOffer> nearbyOffers;
  final LatLng? towDestination;
  final RouteEstimate? route;
  final RouteEstimate? towRoute;
  final bool isTow;

  const _LiveMap({
    required this.lat,
    required this.lng,
    this.address,
    this.technicianLocation,
    this.nearbyOffers = const [],
    this.towDestination,
    this.route,
    this.towRoute,
    this.isTow = false,
  });

  @override
  Widget build(BuildContext context) {
    final tech = technicianLocation;
    final destination = towDestination;
    final offerMarkers = nearbyOffers
        .where((offer) => offer.lat != null && offer.lng != null)
        .toList(growable: false);
    final center = tech == null
        ? LatLng(lat, lng)
        : LatLng((lat + tech.lat) / 2, (lng + tech.lng) / 2);
    final routePoints = route?.points ??
        (tech == null
            ? <LatLng>[]
            : [LatLng(tech.lat, tech.lng), LatLng(lat, lng)]);
    final towRoutePoints = towRoute?.points ??
        (destination == null ? <LatLng>[] : [LatLng(lat, lng), destination]);
    final boundsPoints = [
      LatLng(lat, lng),
      if (tech != null) LatLng(tech.lat, tech.lng),
      if (destination != null) destination,
      ...offerMarkers.map((offer) => LatLng(offer.lat!, offer.lng!)),
      ...routePoints,
      ...towRoutePoints,
    ];
    final initialZoom = tech == null
        ? 14.0
        : route != null && route!.distanceKm > 20
            ? 10.0
            : route != null && route!.distanceKm > 10
                ? 11.0
                : route != null && route!.distanceKm > 5
                    ? 12.0
                    : 13.0;

    return Container(
      height: AppResponsive.mapHeight(
        context,
        compact: 220,
        regular: 256,
        tablet: 300,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            key: ValueKey(
              '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)},'
              '${tech?.lat.toStringAsFixed(5)},${tech?.lng.toStringAsFixed(5)}',
            ),
            options: MapOptions(
              initialCenter: center,
              initialZoom: initialZoom,
              initialCameraFit: boundsPoints.length >= 2
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(boundsPoints),
                      padding: const EdgeInsets.all(48),
                    )
                  : null,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: AppColors.primary.withValues(alpha: 0.55),
                      strokeWidth: 3,
                    ),
                  ],
                ),
              if (towRoutePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: towRoutePoints,
                      color: AppColors.emergency.withValues(alpha: 0.62),
                      strokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child:
                            Icon(Icons.circle, color: Colors.white, size: 12),
                      ),
                      ),
                    ),
                  if (destination != null)
                    Marker(
                      point: destination,
                      width: 42,
                      height: 42,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.emergency,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.emergency.withValues(alpha: 0.35),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  if (tech != null)
                    Marker(
                      point: LatLng(tech.lat, tech.lng),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.technicianMarker,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.technicianMarker
                                  .withValues(alpha: 0.35),
                              blurRadius: 14,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.build_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  if (tech == null)
                    ...offerMarkers.map(
                      (offer) => Marker(
                        point: LatLng(offer.lat!, offer.lng!),
                        width: 34,
                        height: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.technicianMarker,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.technicianMarker
                                    .withValues(alpha: 0.28),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_shipping_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),
          if (address?.trim().isNotEmpty == true)
            Positioned(
              bottom: tech == null ? 16 : 54,
              left: 16,
              right: 64,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Gap(8),
                    Flexible(
                      child: Text(
                        address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (tech != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 64,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.technicianMarker,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Gap(8),
                    Flexible(
                      child: Text(
                        'Tecnico en camino - actualizado ${AppHelpers.formatTime(tech.updatedAt.toLocal())}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (route != null)
            Positioned(
              top: isTow && destination != null ? 56 : 16,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    route!.isApproximate
                        ? 'Ruta estimada: ${route!.distanceLabel}'
                        : 'Ruta por carretera: ${route!.distanceLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          if (isTow && destination != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    towRoute == null
                        ? 'Destino de grúa seleccionado'
                        : 'Traslado: ${towRoute!.distanceLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          // My location button
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.my_location,
                  color: AppColors.onSurface, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Technician Card (Glassmorphism) ──────────────────────────────────────────

class _TechnicianCard extends StatelessWidget {
  final Emergency emergency;
  final RouteEstimate? route;
  final VoidCallback onCancel;

  const _TechnicianCard({
    required this.emergency,
    required this.route,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final technicianName = emergency.tecnicoNombre?.trim().isNotEmpty == true
        ? emergency.tecnicoNombre!.trim()
        : 'Tecnico asignado';
    final rating = emergency.tecnicoRating;
    final ratingText =
        rating == null || rating <= 0 ? 'Sin calificacion' : rating.toStringAsFixed(1);
    final specialty = emergency.tecnicoSpecialty?.trim().isNotEmpty == true
        ? emergency.tecnicoSpecialty!.trim()
        : emergency.pricingServiceName ?? 'Tecnico verificado';
    final etaText = route == null ? 'ETA' : '${route!.durationMinutes} min';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.04),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            children: [
              // Tech info row
              Row(
                children: [
                  // Avatar with verified badge
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        child: Text(
                          AppHelpers.getInitials(technicianName),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.verified,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          technicianName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const Gap(4),
                            Text(
                              ratingText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              ' \u2022 ',
                              style: TextStyle(
                                color: AppColors.secondary.withValues(alpha: 0.5),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                specialty,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ETA badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me,
                            size: 14, color: AppColors.primary),
                        const Gap(4),
                        Text(
                          etaText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.call,
                      label: 'Llamar',
                      onTap: () => _callPhone(context, emergency.tecnicoPhone),
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.chat_bubble,
                      label: 'Chat',
                      onTap: () => context.push(
                        AppRoutes.driverChat,
                        extra: emergency.id,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(16),

              // Cancel button
              TextButton(
                onPressed: emergency.estado == AppConstants.statusCancelled ||
                        emergency.estado == AppConstants.statusCompleted
                    ? null
                    : onCancel,
                child: const Text(
                  'Cancelar servicio',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.onSurface),
            const Gap(8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Searching Card ───────────────────────────────────────────────────────────

class _OfferSelectionCard extends StatefulWidget {
  final AsyncValue<List<TechnicianOffer>> offersAsync;
  final String? emergencyType;
  final bool isChoosing;
  final ValueChanged<TechnicianOffer> onAccept;
  final VoidCallback onCancel;

  const _OfferSelectionCard({
    required this.offersAsync,
    required this.emergencyType,
    required this.isChoosing,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  State<_OfferSelectionCard> createState() => _OfferSelectionCardState();
}

class _OfferSelectionCardState extends State<_OfferSelectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: widget.offersAsync.when(
        loading: () => _WaitingForOffers(
          animation: _ctrl,
          onCancel: widget.onCancel,
          isBusy: widget.isChoosing,
        ),
        error: (_, __) => _WaitingForOffers(
          animation: _ctrl,
          onCancel: widget.onCancel,
          isBusy: widget.isChoosing,
          message: 'No se pudieron cargar ofertas. Seguimos escuchando.',
        ),
        data: (offers) {
          final pending = EmergencyMatchPolicy.visibleRanked<TechnicianOffer>(
            items: offers.where((offer) => offer.status == 'pendiente'),
            emergencyType: widget.emergencyType,
            distanceKm: (offer) => offer.distanceKm,
            rating: (offer) => offer.rating,
          );
          if (pending.isEmpty) {
            return _WaitingForOffers(
              animation: _ctrl,
              onCancel: widget.onCancel,
              isBusy: widget.isChoosing,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.engineering_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pending.length} tecnico${pending.length == 1 ? '' : 's'} respondieron',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Text(
                          'Elige quien atendera tu solicitud.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(16),
              ...pending.map(
                (offer) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TechnicianOfferTile(
                    offer: offer,
                    emergencyType: widget.emergencyType,
                    isChoosing: widget.isChoosing,
                    onAccept: () => widget.onAccept(offer),
                  ),
                ),
              ),
              const Gap(6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.isChoosing ? null : widget.onCancel,
                  icon: widget.isChoosing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    widget.isChoosing ? 'Procesando...' : 'Cancelar solicitud',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WaitingForOffers extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onCancel;
  final bool isBusy;
  final String message;

  const _WaitingForOffers({
    required this.animation,
    required this.onCancel,
    required this.isBusy,
    this.message = 'Los tecnicos disponibles podran responder en tiempo real.',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RotationTransition(
          turns: animation,
          child: const Icon(Icons.sync, color: AppColors.primary, size: 32),
        ),
        const Gap(16),
        const Text(
          'Esperando respuestas de tecnicos...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const Gap(4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.secondary),
        ),
        const Gap(24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : onCancel,
            icon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.close_rounded, size: 18),
            label: Text(isBusy ? 'Procesando...' : 'Cancelar solicitud'),
          ),
        ),
        const Gap(8),
        const Text(
          'Puedes cancelar sin cargo mientras no elijas un tecnico.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _TechnicianOfferTile extends StatelessWidget {
  final TechnicianOffer offer;
  final String? emergencyType;
  final bool isChoosing;
  final VoidCallback onAccept;

  const _TechnicianOfferTile({
    required this.offer,
    required this.emergencyType,
    required this.isChoosing,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final specialty = offer.specialty?.trim().isNotEmpty == true
        ? offer.specialty!.trim()
        : 'Tecnico verificado';
    final band = EmergencyMatchPolicy.bandFor(
      emergencyType: emergencyType,
      distanceKm: offer.distanceKm,
    );
    final amountLabel = offer.offeredAmount == null
        ? 'Por acordar'
        : AppHelpers.formatCurrency(offer.offeredAmount!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceContainerHigh,
                child: Text(
                  AppHelpers.getInitials(offer.name),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  offer.etaLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const Gap(8),
                const Expanded(
                  child: Text(
                    'Precio ofertado',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      amountLabel,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          if (band != null) ...[
            Row(
              children: [
                Icon(
                  band.rank == 0
                      ? Icons.near_me_rounded
                      : Icons.radar_rounded,
                  size: 16,
                  color: band.rank == 0 ? AppColors.success : AppColors.primary,
                ),
                const Gap(6),
                Expanded(
                  child: Text(
                    band.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: band.rank == 0
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(10),
          ],
          Row(
            children: [
              _OfferMetric(
                icon: Icons.star_rounded,
                label: offer.ratingLabel,
                color: Colors.amber.shade700,
              ),
              const Gap(8),
              _OfferMetric(
                icon: Icons.route_outlined,
                label: offer.distanceLabel,
                color: AppColors.secondary,
              ),
              const Gap(8),
              _OfferMetric(
                icon: Icons.assignment_turned_in_outlined,
                label: '${offer.totalServices} servicios',
                color: AppColors.tertiary,
              ),
            ],
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isChoosing ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Elegir tecnico'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _OfferMetric({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const Gap(4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchingCard extends StatefulWidget {
  final VoidCallback onCancel;
  final bool isCancelling;

  const _SearchingCard({
    required this.onCancel,
    required this.isCancelling,
  });

  @override
  State<_SearchingCard> createState() => _SearchingCardState();
}

class _SearchingCardState extends State<_SearchingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          RotationTransition(
            turns: _ctrl,
            child: const Icon(Icons.sync, color: AppColors.primary, size: 32),
          ),
          const Gap(16),
          const Text(
            'Buscando tecnico disponible...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const Gap(4),
          const Text(
            'Estamos buscando el tecnico mas cercano',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondary,
            ),
          ),
          const Gap(24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.isCancelling ? null : widget.onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.28),
                ),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              icon: widget.isCancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.close_rounded, size: 18),
              label: Text(
                widget.isCancelling ? 'Cancelando...' : 'Cancelar solicitud',
              ),
            ),
          ),
          const Gap(8),
          const Text(
            'Puedes cancelar sin cargo mientras ningun tecnico haya aceptado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline Stepper ─────────────────────────────────────────────────────────

class _TimelineStepper extends StatelessWidget {
  final Emergency emergency;

  const _TimelineStepper({required this.emergency});

  @override
  Widget build(BuildContext context) {
    final currentStatus = emergency.estado == AppConstants.statusCompleted
        ? AppConstants.assignFinished
        : emergency.asignacionEstado ?? '';
    final steps = [
      _TimelineStep(
        title: 'Solicitud enviada',
        subtitle:
            '${emergency.direccion ?? 'Ecuador'} \u2022 ${AppHelpers.formatTime(emergency.fecha)}',
        status: _StepStatus.completed,
      ),
      _TimelineStep(
        title: 'Servicio aceptado',
        subtitle: 'Tecnico asignado',
        status: _isAtLeast(currentStatus, AppConstants.assignAccepted)
            ? _StepStatus.completed
            : _StepStatus.pending,
      ),
      _TimelineStep(
        title: 'En camino',
        subtitle: emergency.hasTechnician
            ? '${emergency.tecnicoNombre} esta cerca de ti'
            : 'Esperando asignacion',
        status: currentStatus == AppConstants.assignEnRoute
            ? _StepStatus.active
            : _isAtLeast(currentStatus, AppConstants.assignAttending)
                ? _StepStatus.completed
                : _StepStatus.pending,
      ),
      _TimelineStep(
        title: 'Finalizado',
        subtitle: 'Confirmacion de llegada',
        status: currentStatus == AppConstants.assignFinished
            ? _StepStatus.completed
            : _StepStatus.pending,
        isLast: true,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: steps.map((step) => _TimelineStepWidget(step: step)).toList(),
      ),
    );
  }

  bool _isAtLeast(String current, String target) {
    const order = [
      AppConstants.assignAccepted,
      AppConstants.assignEnRoute,
      AppConstants.assignAttending,
      AppConstants.assignFinished,
    ];
    final ci = order.indexOf(current);
    final ti = order.indexOf(target);
    return ci >= 0 && ti >= 0 && ci >= ti;
  }
}

enum _StepStatus { completed, active, pending }

class _TimelineStep {
  final String title;
  final String subtitle;
  final _StepStatus status;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.status,
    this.isLast = false,
  });
}

class _TimelineStepWidget extends StatelessWidget {
  final _TimelineStep step;

  const _TimelineStepWidget({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicator column
        SizedBox(
          width: 24,
          child: Column(
            children: [
              // Dot
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: step.status == _StepStatus.completed
                      ? AppColors.primary
                      : step.status == _StepStatus.active
                          ? Colors.white
                          : AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                  border: step.status == _StepStatus.active
                      ? Border.all(color: AppColors.primary, width: 4)
                      : null,
                ),
                child: step.status == _StepStatus.completed
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : step.status == _StepStatus.active
                        ? Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
              ),
              // Line
              if (!step.isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: AppColors.secondaryContainer,
                ),
            ],
          ),
        ),
        const Gap(24),
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: step.isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: step.status == _StepStatus.active
                        ? AppColors.primary
                        : step.status == _StepStatus.pending
                            ? AppColors.secondary.withValues(alpha: 0.5)
                            : AppColors.onSurface,
                  ),
                ),
                Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: step.status == _StepStatus.pending
                        ? AppColors.secondary.withValues(alpha: 0.5)
                        : AppColors.secondary,
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
