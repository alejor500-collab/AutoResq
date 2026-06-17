import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/payment_methods.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/utils/app_responsive.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/in_app_message_notice.dart';
import '../../../../shared/widgets/notification_center_sheet.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/widgets/chat_notification_bell.dart';
import '../../../map/presentation/widgets/map_widget.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';

Future<void> _callPhone(BuildContext context, String? phone) async {
  final digits = phone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
  if (digits.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay telefono registrado para llamar')),
    );
    return;
  }
  final ok = await launchUrl(
    Uri(scheme: 'tel', path: digits),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir la app de telefono')),
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

// ─── Substate local para esta pantalla ───────────────────────────────────────
final _activeSubstateProvider = StateProvider.autoDispose<String>(
  (ref) => AppConstants.assignEnRoute,
);

// ─── Entry point ─────────────────────────────────────────────────────────────

class ActiveServiceScreen extends ConsumerWidget {
  final String emergencyId;

  const ActiveServiceScreen({super.key, required this.emergencyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(watchEmergencyProvider(emergencyId));

    return stream.when(
      loading: () => const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(e.toString())),
      ),
      data: (emergency) => _ActiveServiceBody(emergency: emergency),
    );
  }
}

// ─── Body con subestados ──────────────────────────────────────────────────────

class _ActiveServiceBody extends ConsumerStatefulWidget {
  final Emergency emergency;

  const _ActiveServiceBody({required this.emergency});

  @override
  ConsumerState<_ActiveServiceBody> createState() => _ActiveServiceBodyState();
}

class _ActiveServiceBodyState extends ConsumerState<_ActiveServiceBody> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _attendingTimer;
  StreamSubscription<Position>? _positionSub;
  ProviderSubscription<AsyncValue<int>>? _unreadChatSubscription;
  DateTime? _arrivalStartedAt;
  Position? _currentPosition;
  int _lastUnreadChatCount = 0;
  int _attendingSeconds = 0;
  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _unreadChatSubscription = ref.listenManual<AsyncValue<int>>(
      unreadChatCountProvider,
      _handleUnreadChatCount,
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.emergency.asignacionEstado == AppConstants.assignAttending) {
        ref.read(_activeSubstateProvider.notifier).state =
            AppConstants.assignAttending;
        _arrivalStartedAt =
            widget.emergency.asignacionLlegadaFecha ?? DateTime.now();
        _startAttendingTimer();
      }
      _startLiveLocationUpdates();
    });
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
      onTap: _openChat,
    );
  }

  void _openChat() {
    context.push(
      AppRoutes.technicianChat,
      extra: widget.emergency.id,
    );
  }

  Future<void> _openNotifications() async {
    await showNotificationCenterSheet(
      context: context,
      ref: ref,
      onNotificationTap: (notification) async {
        if (!mounted) return;
        final referenceId = notification.referenceId;
        switch (notification.type) {
          case 'nuevo_mensaje':
            if (referenceId?.isNotEmpty == true) {
              context.push(AppRoutes.technicianChat, extra: referenceId);
            }
            return;
          case 'nueva_solicitud':
          case 'solicitud_cancelada':
            context.go(AppRoutes.technicianHome, extra: 1);
            return;
          default:
            if (referenceId?.isNotEmpty == true) {
              context.go(AppRoutes.activeService, extra: referenceId);
            }
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant _ActiveServiceBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emergency.tecnicoId != widget.emergency.tecnicoId) {
      _startLiveLocationUpdates();
    }
    if (oldWidget.emergency.asignacionLlegadaFecha !=
        widget.emergency.asignacionLlegadaFecha) {
      _arrivalStartedAt = widget.emergency.asignacionLlegadaFecha;
      if (widget.emergency.asignacionEstado == AppConstants.assignAttending) {
        _startAttendingTimer();
      }
    }
    if (oldWidget.emergency.asignacionEstado !=
            widget.emergency.asignacionEstado &&
        widget.emergency.asignacionEstado == AppConstants.assignAttending) {
      ref.read(_activeSubstateProvider.notifier).state =
          AppConstants.assignAttending;
      _arrivalStartedAt =
          widget.emergency.asignacionLlegadaFecha ?? DateTime.now();
      _startAttendingTimer();
    }
  }

  Future<void> _startLiveLocationUpdates() async {
    final technicianId = widget.emergency.tecnicoId;
    if (technicianId == null || technicianId.isEmpty) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _positionSub?.cancel();
    final current = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await _publishLiveLocation(current);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      _publishLiveLocation,
      onError: (_) {},
    );
  }

  Future<void> _publishLiveLocation(Position position) async {
    final technicianId = widget.emergency.tecnicoId;
    if (technicianId == null || technicianId.isEmpty) return;
    if (mounted) {
      setState(() => _currentPosition = position);
    }
    try {
      await ref.read(supabaseClientProvider).from(
        AppConstants.tableUbicacionesTecnico,
      ).upsert({
        'tecnico_id': technicianId,
        'latitud': position.latitude,
        'longitud': position.longitude,
        'actualizado_en': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'tecnico_id');
    } catch (_) {}
  }

  void _startAttendingTimer() {
    _attendingTimer?.cancel();
    if (mounted) setState(_syncAttendingSeconds);
    _attendingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_syncAttendingSeconds);
    });
  }

  void _syncAttendingSeconds() {
    final startedAt =
        widget.emergency.asignacionLlegadaFecha ?? _arrivalStartedAt;
    if (startedAt == null) {
      _attendingSeconds = 0;
      return;
    }
    final seconds = DateTime.now().difference(startedAt).inSeconds;
    _attendingSeconds = seconds < 0 ? 0 : seconds;
  }

  String _formatElapsed() {
    final m = _attendingSeconds ~/ 60;
    final s = _attendingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _onHeLlegado() async {
    final asignacionId = widget.emergency.asignacionId;
    final arrivedAt = DateTime.now();
    if (asignacionId != null && asignacionId.isNotEmpty) {
      try {
        await ref
            .read(supabaseClientProvider)
            .from(AppConstants.tableAsignaciones)
            .update({
              'estado': AppConstants.assignAttending,
              'fecha_llegada': arrivedAt.toUtc().toIso8601String(),
            })
            .eq('id', asignacionId);
        await ref
            .read(supabaseClientProvider)
            .from(AppConstants.tableEmergencias)
            .update({'estado': AppConstants.statusAttended})
            .eq('id', widget.emergency.id);
        unawaited(_notifyDriverAboutArrival(widget.emergency.id));
      } catch (_) {}
    }
    if (!mounted) return;
    _arrivalStartedAt = arrivedAt;
    ref.read(_activeSubstateProvider.notifier).state =
        AppConstants.assignAttending;
    _startAttendingTimer();
  }

  Future<void> _notifyDriverAboutArrival(String emergencyId) async {
    try {
      await ref.read(supabaseClientProvider).functions.invoke(
        'notify-emergency-update',
        body: {
          'emergency_id': emergencyId,
          'type': 'tecnico_en_ruta',
        },
      );
    } catch (_) {
      // La confirmacion de llegada no debe fallar si el canal push no responde.
    }
  }

  Future<void> _cancelByTechnician() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Cancelar atencion'),
        content: const Text(
          'Sabemos que pueden surgir imprevistos. Si cancelas ahora, avisaremos al conductor y la solicitud volvera a buscar ayuda. Para cuidar la confianza del servicio, esta cancelacion quedara registrada y podria generar una penalizacion operativa en tu proxima asignacion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir atendiendo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar atencion'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(emergencyNotifierProvider.notifier)
        .cancelTechnicianService(widget.emergency.id);
    if (!mounted) return;
    if (ok) {
      AppHelpers.showSnackBar(
        context,
        'Atencion cancelada. El conductor fue notificado.',
        isSuccess: true,
      );
      context.go(AppRoutes.technicianHome);
      return;
    }

    AppHelpers.showSnackBar(
      context,
      ref.read(emergencyNotifierProvider).error ??
          'No se pudo cancelar la atencion.',
      isError: true,
    );
  }

  @override
  void dispose() {
    _attendingTimer?.cancel();
    _positionSub?.cancel();
    _unreadChatSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final substate = ref.watch(_activeSubstateProvider);
    final emergency = widget.emergency;
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final lat = emergency.lat ?? AppConstants.defaultLat;
    final lng = emergency.lng ?? AppConstants.defaultLng;
    final towDestinationLat = _snapshotDouble(emergency, 'destination_lat');
    final towDestinationLng = _snapshotDouble(emergency, 'destination_lng');
    final currentPosition = _currentPosition;
    final routeEstimate = currentPosition == null
        ? null
        : ref.watch(
            technicianRouteEstimateProvider(
              (
                originLat: currentPosition.latitude,
                originLng: currentPosition.longitude,
                destinationLat: lat,
                destinationLng: lng,
              ),
            ),
          );
    final routePoints = routeEstimate?.valueOrNull?.points ??
        (currentPosition == null
            ? <LatLng>[]
            : [
                LatLng(currentPosition.latitude, currentPosition.longitude),
                LatLng(lat, lng),
              ]);
    final hasTowDestination = _isTowEmergency(emergency) &&
        towDestinationLat != null &&
        towDestinationLng != null;
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
    final towRoutePoints = towRouteEstimate?.valueOrNull?.points ??
        (hasTowDestination
            ? [LatLng(lat, lng), LatLng(towDestinationLat, towDestinationLng)]
            : <LatLng>[]);
    final markers = [
      if (currentPosition != null)
        technicianMarker(
          currentPosition.latitude,
          currentPosition.longitude,
          name: 'Tú',
        ),
      emergencyMarker(lat, lng),
      if (hasTowDestination)
        MapMarker(
          lat: towDestinationLat,
          lng: towDestinationLng,
          color: AppColors.emergency,
          icon: Icons.flag_rounded,
          label: 'Destino',
        ),
    ];
    final isEnRoute = substate == AppConstants.assignEnRoute;
    final horizontal = AppResponsive.horizontalPadding(context);
    final isShort = AppResponsive.isShort(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawerScrimColor: Colors.transparent,
      onDrawerChanged: (isOpened) => setState(() => _isDrawerOpen = isOpened),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Column(
            children: [
          // ─── Mapa ────────────────────────────────────────────────────
          Expanded(
            flex: isShort ? 2 : (isEnRoute ? 3 : 2),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AppMapWidget(
                    lat: lat,
                    lng: lng,
                    zoom: currentPosition == null ? 15 : 13,
                    markers: markers,
                    polylines: [
                      if (routePoints.length >= 2)
                        MapPolyline(
                          points: routePoints,
                          color: AppColors.primary.withValues(alpha: 0.62),
                          strokeWidth: 4,
                        ),
                      if (towRoutePoints.length >= 2)
                        MapPolyline(
                          points: towRoutePoints,
                          color: AppColors.emergency.withValues(alpha: 0.62),
                          strokeWidth: 3,
                        ),
                    ],
                    fitBounds: currentPosition != null || hasTowDestination,
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontal,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Botón atrás
                        Material(
                          color: Colors.white.withValues(alpha: 0.88),
                          shape: const CircleBorder(),
                          elevation: 2,
                          shadowColor: Colors.black12,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              setState(() => _isDrawerOpen = true);
                              _scaffoldKey.currentState?.openDrawer();
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.menu_rounded,
                                size: 22,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Chip de estado flotante centrado
                        _StatusFloatingChip(
                          label: isEnRoute ? 'EN RUTA' : 'ATENDIENDO',
                          color: isEnRoute
                              ? AppColors.primary
                              : AppColors.warning,
                          icon: isEnRoute
                              ? Icons.navigation_rounded
                              : Icons.build_rounded,
                        ),
                        const Spacer(),
                        ChatNotificationBell(
                          onTap: _openNotifications,
                          iconColor: AppColors.secondary,
                          backgroundColor: Colors.white.withValues(alpha: 0.88),
                        ),
                        const Gap(8),
                        Material(
                          color: Colors.white.withValues(alpha: 0.88),
                          shape: const CircleBorder(),
                          elevation: 2,
                          shadowColor: Colors.black12,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => context.push(AppRoutes.profile),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: UserAvatar(
                                imageUrl: user?.avatarUrl,
                                name: user?.name ?? 'T',
                                radius: 17,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Tarjeta inferior ─────────────────────────────────────────
          Expanded(
            flex: isShort ? 3 : (isEnRoute ? 2 : 3),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 24,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: AppFadeSlideIn(
                offsetY: 10,
                child: isEnRoute
                    ? _EnRoutePanel(
                        emergency: emergency,
                        onHeLlegado: _onHeLlegado,
                        onCancel: _cancelByTechnician,
                      )
                    : _AttendingPanel(
                        emergency: emergency,
                        elapsed: _formatElapsed(),
                        onCancel: _cancelByTechnician,
                      ),
              ),
            ),
          ),
            ],
          ),
          Positioned.fill(
            child: DrawerBackdropBlur(visible: _isDrawerOpen),
          ),
        ],
      ),
    );
  }
}

// ─── Panel EN RUTA ────────────────────────────────────────────────────────────

class _EnRoutePanel extends StatelessWidget {
  final Emergency emergency;
  final VoidCallback onHeLlegado;
  final VoidCallback onCancel;

  const _EnRoutePanel({
    required this.emergency,
    required this.onHeLlegado,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final horizontal = AppResponsive.horizontalPadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ETA + dirección (si existe)
          if (emergency.direccion != null) ...[
            const Text(
              'En camino',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.onSurface,
                letterSpacing: 0,
              ),
            ),
            const Gap(2),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textSecondary),
                const Gap(4),
                Expanded(
                  child: Text(
                    emergency.direccion!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(16),
            const Divider(height: 1, color: AppColors.border),
            const Gap(16),
          ],

          // Conductor
          Row(
            children: [
              UserAvatar(
                name: emergency.driverName ?? 'C',
                radius: 22,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emergency.driverName ?? 'Conductor',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (emergency.vehiculoId != null)
                      const Text(
                        'Vehículo registrado',
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
          _ServiceInfoLine(
            icon: PaymentMethods.icon(emergency.paymentMethod),
            text: 'Pago: ${PaymentMethods.label(emergency.paymentMethod)}',
          ),
          if (emergency.agreedAmount != null) ...[
            const Gap(10),
            _ServiceInfoLine(
              icon: Icons.local_offer_outlined,
              text:
                  'Precio aproximado ofertado: ${AppHelpers.formatCurrency(emergency.agreedAmount!)}',
            ),
          ],
          const Gap(16),

          // Llamar + Chat
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Llamar',
                  variant: AppButtonVariant.outline,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18,
                      color: AppColors.onSurface),
                  onPressed: () => _callPhone(context, emergency.driverPhone),
                  height: 48,
                ),
              ),
              const Gap(12),
              Expanded(
                child: AppButton(
                  label: 'Chat',
                  variant: AppButtonVariant.outline,
                  prefixIcon: const Icon(Icons.chat_bubble_outline, size: 18,
                      color: AppColors.onSurface),
                  onPressed: () => context.push(
                    AppRoutes.technicianChat,
                    extra: emergency.id,
                  ),
                  height: 48,
                ),
              ),
            ],
          ),
          const Gap(12),

          // He llegado
          AppButton(
            label: 'He llegado',
            onPressed: onHeLlegado,
            variant: AppButtonVariant.success,
          ),
          const Gap(10),
          AppButton(
            label: 'Cancelar atencion',
            variant: AppButtonVariant.danger,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// ─── Panel ATENDIENDO ─────────────────────────────────────────────────────────

class _ServiceInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ServiceInfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const Gap(10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendingPanel extends StatelessWidget {
  final Emergency emergency;
  final String elapsed;
  final VoidCallback onCancel;

  const _AttendingPanel({
    required this.emergency,
    required this.elapsed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final horizontal = AppResponsive.horizontalPadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Atendiendo al cliente',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const Gap(4),
          Text(
            emergency.driverName ?? 'Conductor',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(10),
          _ServiceInfoLine(
            icon: PaymentMethods.icon(emergency.paymentMethod),
            text: 'Pago: ${PaymentMethods.label(emergency.paymentMethod)}',
          ),
          if (emergency.agreedAmount != null) ...[
            const Gap(10),
            _ServiceInfoLine(
              icon: Icons.local_offer_outlined,
              text:
                  'Precio aproximado ofertado: ${AppHelpers.formatCurrency(emergency.agreedAmount!)}',
            ),
          ],
          const Gap(22),

          // Contador
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusCard),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                elapsed,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: AppColors.warning,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          const Gap(28),

          // Chat
          AppButton(
            label: 'Chat',
            variant: AppButtonVariant.outline,
            prefixIcon: const Icon(Icons.chat_bubble_outline, size: 18,
                color: AppColors.onSurface),
            onPressed: () => context.push(
              AppRoutes.technicianChat,
              extra: emergency.id,
            ),
          ),
          const Gap(12),

          // Finalizar
          AppButton(
            label: 'Finalizar servicio',
            variant: AppButtonVariant.success,
            onPressed: () => context.pushReplacement(
              AppRoutes.serviceClosure,
              extra: {
                'emergencyId': emergency.id,
                'asignacionId': emergency.asignacionId,
                'technicianId': emergency.tecnicoId,
                'driverId': emergency.usuarioId,
                'driverName': emergency.driverName ?? 'Conductor',
                'clasificacionIa': emergency.clasificacionIa,
                'duration': elapsed,
                'amount': emergency.agreedAmount?.toStringAsFixed(2),
              },
            ),
          ),
          const Gap(10),

          // Cancelacion secundaria: no debe competir con la accion principal.
          Center(
            child: TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: const Text('Cancelar atencion'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip de estado flotante ──────────────────────────────────────────────────

class _StatusFloatingChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusFloatingChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const Gap(6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
