import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/payment_methods.dart';
import '../../../../core/constants/technician_specialties.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/role_provider.dart';
import '../../../../shared/providers/technician_stats_provider.dart';
import '../../../../shared/utils/app_responsive.dart';
import '../../../../shared/widgets/animated_pressable.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/in_app_message_notice.dart';
import '../../../../shared/widgets/notification_center_sheet.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/widgets/chat_notification_bell.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../map/presentation/widgets/map_widget.dart';
import 'incoming_request_sheet.dart';
import '../providers/emergency_provider.dart';
import '../widgets/technician_offer_amount_sheet.dart';
import '../../domain/entities/emergency_entity.dart';

class TechnicianHomeScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const TechnicianHomeScreen({super.key, this.initialTab = 2});

  @override
  ConsumerState<TechnicianHomeScreen> createState() =>
      _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends ConsumerState<TechnicianHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mapController = MapController();
  ProviderSubscription<AsyncValue<List<Emergency>>>?
      _pendingEmergenciesSubscription;
  ProviderSubscription<AsyncValue<Emergency?>>? _activeServiceSubscription;
  ProviderSubscription<AsyncValue<int>>? _unreadChatSubscription;
  Timer? _bannerDismissTimer;
  int _navIndex = 0;
  int _lastUnreadChatCount = 0;
  bool? _isAvailable;
  bool _activeWarningShown = false;
  String? _autoOpenedActiveServiceId;
  bool _pendingEmergencyFeedSeeded = false;
  final Set<String> _knownPendingEmergencyIds = <String>{};
  List<Emergency> _bannerEmergencies = const [];

  @override
  void initState() {
    super.initState();
    _navIndex = widget.initialTab.clamp(0, 4);
    _pendingEmergenciesSubscription =
        ref.listenManual<AsyncValue<List<Emergency>>>(
      technicianPendingEmergenciesProvider,
      (previous, next) {
        if (!mounted) return;
        final available = _isAvailable ??
            ref.read(authNotifierProvider).value?.isAvailable ??
            false;
        next.whenData(
          (emergencies) => _handlePendingEmergencyUpdate(
            emergencies,
            isAvailable: available,
          ),
        );
      },
    );
    _activeServiceSubscription =
        ref.listenManual<AsyncValue<Emergency?>>(
      activeTechnicianEmergencyProvider,
      _handleActiveServiceUpdate,
    );
    _unreadChatSubscription = ref.listenManual<AsyncValue<int>>(
      unreadChatCountProvider,
      _handleUnreadChatCount,
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final user = ref.read(authNotifierProvider).value ??
          ref.read(authStateProvider).valueOrNull;
      if (user?.isApproved != true) return;
      await ref.read(mapNotifierProvider.notifier).getCurrentLocation();
      if (!mounted) return;
      final active = await ref
          .read(emergencyNotifierProvider.notifier)
          .loadActiveTechnicianEmergency();
      if (!mounted) return;
      if (active != null) {
        _showActiveServiceDialog(active, fromStartup: true);
        return;
      }
      ref.read(emergencyNotifierProvider.notifier).loadPendingEmergencies();
    });
  }

  @override
  void dispose() {
    _bannerDismissTimer?.cancel();
    _pendingEmergenciesSubscription?.close();
    _activeServiceSubscription?.close();
    _unreadChatSubscription?.close();
    super.dispose();
  }

  void _handleActiveServiceUpdate(
    AsyncValue<Emergency?>? previous,
    AsyncValue<Emergency?> next,
  ) {
    final active = next.valueOrNull;
    final previousActive = previous?.valueOrNull;
    if (!mounted) return;
    if (active == null) {
      _activeWarningShown = false;
      return;
    }

    if (previousActive?.id == active.id) return;
    ref.invalidate(technicianEmergencyHistoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openActiveService(active, auto: true);
    });
  }

  void _openActiveService(Emergency active, {bool auto = false}) {
    if (!mounted) return;
    if (auto && _autoOpenedActiveServiceId == active.id) return;
    if (auto) _autoOpenedActiveServiceId = active.id;
    _activeWarningShown = true;
    context.push(AppRoutes.activeService, extra: active.id);
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
        .loadActiveTechnicianEmergency();
    if (!mounted) return;
    if (active?.asignacionId?.isNotEmpty == true) {
      context.push(AppRoutes.technicianChat, extra: active!.id);
      return;
    }
    setState(() => _navIndex = 3);
  }

  Future<void> _openNotifications() async {
    if (!mounted) return;
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
            } else {
              setState(() => _navIndex = 3);
            }
            return;
          case 'nueva_solicitud':
          case 'solicitud_cancelada':
            ref.invalidate(technicianPendingEmergenciesProvider);
            setState(() => _navIndex = 1);
            return;
          default:
            if (referenceId?.isNotEmpty == true) {
              context.push(AppRoutes.activeService, extra: referenceId);
            }
        }
      },
    );
  }

  void _showActiveServiceDialog(
    Emergency active, {
    bool fromStartup = false,
  }) {
    if (!mounted || _activeWarningShown) return;
    _activeWarningShown = true;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Servicio en proceso'),
        content: const Text(
          'Tienes una emergencia activa. Puedes revisar el home, pero no podras aceptar otra solicitud hasta finalizar el servicio actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openActiveService(active);
            },
            child: const Text('Ver servicio'),
          ),
        ],
      ),
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
      case 1:
      case 2:
      case 3:
        setState(() => _navIndex = index);
        break;
      case 4:
        context.push(AppRoutes.profile);
        break;
    }
  }

  Future<void> _recenterToCurrentLocation() async {
    await ref.read(mapNotifierProvider.notifier).getCurrentLocation();
    if (!mounted) return;
    final location = ref.read(mapNotifierProvider).currentLocation;
    if (location == null) return;
    _mapController.move(LatLng(location.lat, location.lng), 15.5);
  }

  Future<void> _refreshEmergencies() {
    ref.invalidate(technicianPendingEmergenciesProvider);
    ref.invalidate(activeTechnicianEmergencyProvider);
    return ref
        .read(emergencyNotifierProvider.notifier)
        .loadPendingEmergencies();
  }

  Future<void> _refreshTechnicianHistory() async {
    ref.invalidate(technicianEmergencyHistoryProvider);
    await _refreshEmergencies();
  }

  Future<void> _toggleAvailability(bool val) async {
    if (!mounted) return;
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    if (val) {
      final pending = await ref
          .read(emergencyNotifierProvider.notifier)
          .getPendingRating('technician');
      if (!mounted) return;
      if (pending != null) {
        _showPendingRatingDialog(pending);
        return;
      }
    }
    setState(() => _isAvailable = val);
    try {
      final rows = await ref
          .read(supabaseClientProvider)
          .from(AppConstants.tableTecnicos)
          .update({'disponible': val})
          .eq('usuario_id', user.id)
          .select('disponible');
      if (!mounted) return;
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
      final persisted = rows.first['disponible'] as bool? ?? val;
      setState(() => _isAvailable = persisted);
      ref.read(technicianAvailableProvider.notifier).state = persisted;
      final updated = user.copyWith(isAvailable: persisted);
      ref.read(authNotifierProvider.notifier).refreshUser(updated);
      ref.read(currentUserProvider.notifier).state = updated;
      if (persisted) {
        final pending =
            ref.read(technicianPendingEmergenciesProvider).valueOrNull ??
                const <Emergency>[];
        if (pending.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showNewEmergencyBanner(pending);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[AutoResQ] toggleAvailability ERROR: $e');
      setState(() => _isAvailable = !val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showPendingRatingDialog(Map<String, dynamic> pendingRating) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Tienes una calificacion pendiente'),
        content: const Text(
          'Califica tu ultimo servicio para poder atender nuevas emergencias.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (!mounted) return;
              context.push(
                AppRoutes.rateDriver,
                extra: {
                  'emergencyId':
                      pendingRating['emergency_id']?.toString() ?? '',
                  'driverId': pendingRating['rated_user_id']?.toString() ?? '',
                  'driverName': pendingRating['rated_user_name']?.toString() ??
                      'Conductor',
                },
              );
            },
            child: const Text('Calificar ahora'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required String technicianName,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.engineering_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      technicianName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      specialty,
                      style: TextStyle(
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
                thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.success;
                  }
                  return AppColors.disabled;
                }),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const Gap(14),
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

  Widget _buildRequestsView({
    required List<Emergency> emergencies,
    required Emergency? activeEmergency,
    required bool isAvailable,
    required bool isLoading,
  }) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshEmergencies,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          92 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Solicitudes activas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                    letterSpacing: 0,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: isLoading ? null : _refreshEmergencies,
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
              ),
            ],
          ),
          const Gap(4),
          Text(
            isAvailable
                ? 'Responde a las solicitudes que puedas atender. El conductor elegira el tecnico.'
                : 'Activa tu disponibilidad para poder responder solicitudes.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const Gap(14),
          if (activeEmergency != null) ...[
            _ActiveServiceNotice(
              emergency: activeEmergency,
              onOpen: () => context.push(
                AppRoutes.activeService,
                extra: activeEmergency.id,
              ),
            ),
            const Gap(12),
          ],
          if (emergencies.isEmpty && !isLoading)
            const _EmptyEmergencyRequests()
          else
            ...emergencies.map(
              (emergency) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EmergencyRequestCard(
                  emergency: emergency,
                  canAccept: isAvailable,
                  isLoading: isLoading,
                  onTap: () => _showIncomingRequest(emergency),
                  onAccept: () => _sendOfferFromList(emergency),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTechnicianHistoryView(
    AsyncValue<List<Emergency>> historyAsync, {
    required Emergency? activeEmergency,
  }) {
    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => _HistoryErrorState(
        message: 'No se pudo cargar tu historial.',
        detail: e.toString(),
        onRetry: () => ref.invalidate(technicianEmergencyHistoryProvider),
      ),
      data: (history) {
        final visibleHistory = activeEmergency == null
            ? history
            : [
                activeEmergency,
                ...history.where(
                  (emergency) => emergency.id != activeEmergency.id,
                ),
              ];

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshTechnicianHistory,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              92 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Historial de solicitudes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: () =>
                        ref.invalidate(technicianEmergencyHistoryProvider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const Gap(4),
              const Text(
                'Aqui veras servicios completados, rechazados y en proceso.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const Gap(14),
              if (visibleHistory.isEmpty)
                const _EmptyTechnicianHistory()
              else
                ...visibleHistory.map(
                  (emergency) {
                    final isActive = activeEmergency?.id == emergency.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: isActive
                          ? _ActiveServiceNotice(
                              emergency: emergency,
                              onOpen: () => context.push(
                                AppRoutes.activeService,
                                extra: emergency.id,
                              ),
                            )
                          : _TechnicianHistoryCard(emergency: emergency),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTechnicianChatHistoryView(
    AsyncValue<List<Emergency>> historyAsync,
    {
    required Emergency? activeEmergency,
  }
  ) {
    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => _HistoryErrorState(
        message: 'No se pudo cargar el historial de chats.',
        detail: e.toString(),
        onRetry: () => ref.invalidate(technicianEmergencyHistoryProvider),
      ),
      data: (history) {
        final chats = history
            .where((emergency) => emergency.asignacionId?.isNotEmpty == true)
            .toList();
        final visibleChats = activeEmergency?.asignacionId?.isNotEmpty == true
            ? [
                activeEmergency!,
                ...chats.where(
                  (emergency) => emergency.id != activeEmergency.id,
                ),
              ]
            : chats;
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshTechnicianHistory,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              92 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chats de servicios',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: () =>
                        ref.invalidate(technicianEmergencyHistoryProvider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const Gap(4),
              const Text(
                'Puedes revisar conversaciones anteriores. Los servicios cerrados quedan en modo lectura.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const Gap(14),
              if (activeEmergency != null) ...[
                _ActiveServiceNotice(
                  emergency: activeEmergency,
                  onOpen: () => context.push(
                    AppRoutes.activeService,
                    extra: activeEmergency.id,
                  ),
                ),
                const Gap(12),
              ],
              if (visibleChats.isEmpty)
                const _EmptyTechnicianChats()
              else
                ...visibleChats
                    .where((emergency) => emergency.id != activeEmergency?.id)
                    .map(
                  (emergency) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TechnicianChatHistoryCard(
                      emergency: emergency,
                      onTap: () => context.push(
                        AppRoutes.technicianChat,
                        extra: emergency.id,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showIncomingRequest(Emergency emergency) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomingRequestSheet(emergency: emergency),
    );
  }

  void _handlePendingEmergencyUpdate(
    List<Emergency> emergencies, {
    required bool isAvailable,
  }) {
    if (!mounted) return;
    final currentIds = emergencies.map((emergency) => emergency.id).toSet();
    if (!_pendingEmergencyFeedSeeded) {
      _pendingEmergencyFeedSeeded = true;
      _knownPendingEmergencyIds
        ..clear()
        ..addAll(currentIds);
      if (emergencies.isNotEmpty && isAvailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showNewEmergencyBanner(emergencies);
        });
      }
      return;
    }

    final newEmergencies = emergencies
        .where((emergency) => !_knownPendingEmergencyIds.contains(emergency.id))
        .toList();
    _knownPendingEmergencyIds
      ..clear()
      ..addAll(currentIds);

    if (newEmergencies.isEmpty || !isAvailable) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showNewEmergencyBanner(newEmergencies);
    });
  }

  void _showNewEmergencyBanner(List<Emergency> emergencies) {
    if (!mounted || emergencies.isEmpty) return;
    if (ref.read(activeTechnicianEmergencyProvider).valueOrNull != null ||
        ref.read(emergencyNotifierProvider).activeEmergency != null) {
      return;
    }

    _bannerDismissTimer?.cancel();
    setState(
        () => _bannerEmergencies = List<Emergency>.unmodifiable(emergencies));
    _bannerDismissTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) {
        setState(() => _bannerEmergencies = const []);
      }
    });
  }

  void _openBannerEmergency() {
    if (_bannerEmergencies.isEmpty) return;
    final first = _bannerEmergencies.first;
    _bannerDismissTimer?.cancel();
    setState(() => _bannerEmergencies = const []);
    _showIncomingRequest(first);
  }

  void _openRequestsTabFromBanner() {
    _bannerDismissTimer?.cancel();
    setState(() {
      _bannerEmergencies = const [];
      _navIndex = 1;
    });
  }

  Future<double?> _promptOfferAmount(Emergency emergency) {
    final suggestedAmount = emergency.protectedTotal ?? emergency.estimatedTotal;
    return showTechnicianOfferAmountSheet(
      context,
      suggestedAmount: suggestedAmount,
      currentOfferAmount: emergency.myOfferedAmount,
      alreadyOffered: emergency.hasMyOffer,
    );
  }

  Future<void> _sendOfferFromList(Emergency emergency) async {
    if (!mounted) return;
    final isAvailable = _isAvailable ??
        ref.read(authNotifierProvider).value?.isAvailable ??
        false;
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa tu disponibilidad para responder solicitudes'),
        ),
      );
      return;
    }

    final offeredAmount = await _promptOfferAmount(emergency);
    if (!mounted || offeredAmount == null) return;

    final ok = await ref
        .read(emergencyNotifierProvider.notifier)
        .createTechnicianOffer(
          emergency.id,
          offeredAmount: offeredAmount,
        );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(technicianPendingEmergenciesProvider);
      ref.invalidate(technicianEmergencyHistoryProvider);
      AppHelpers.showSnackBar(
        context,
        emergency.hasMyOffer
            ? 'Oferta actualizada. El conductor vera tu nuevo valor.'
            : 'Oferta enviada. El conductor decidira si te asigna el servicio.',
        isSuccess: true,
      );
      return;
    }

    final pending =
        await ref.read(emergencyNotifierProvider.notifier).getPendingRating(
              'technician',
            );
    if (!mounted) return;
    if (pending != null) {
      _showPendingRatingDialog(pending);
    } else {
      final active = await ref
          .read(emergencyNotifierProvider.notifier)
          .loadActiveTechnicianEmergency();
      if (!mounted) return;
      if (active != null) {
        _openActiveService(active, auto: true);
        return;
      }
      AppHelpers.showSnackBar(
        context,
        ref.read(emergencyNotifierProvider).error ??
            'No se pudo enviar la oferta',
        isError: true,
      );
    }
  }

  // ── Services tab (SERVICIOS) ──────────────────────────────────────────────

  // ── Pending approval UI ───────────────────────────────────────────────────

  Widget _buildPendingBody(BuildContext context, String? specialty) {
    final profileIncomplete =
        TechnicianSpecialties.normalizeCode(specialty) == null;

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
                letterSpacing: 0,
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
    final technicianHistory = ref.watch(technicianEmergencyHistoryProvider);
    final activeTechnicianEmergency =
        ref.watch(activeTechnicianEmergencyProvider);
    final pendingEmergenciesAsync =
        ref.watch(technicianPendingEmergenciesProvider);
    final user = ref.watch(authNotifierProvider).value;
    final technicianStats = user == null
        ? const AsyncValue<TechnicianStats>.data(TechnicianStats.empty())
        : ref.watch(technicianStatsProvider(user.id));
    final stats = technicianStats.valueOrNull;
    final isAvailable =
        _isAvailable ?? stats?.isAvailable ?? user?.isAvailable ?? false;

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
    final pendingEmergencies =
        pendingEmergenciesAsync.valueOrNull ?? emergencyState.emergencies;
    final activeEmergency =
        activeTechnicianEmergency.valueOrNull ?? emergencyState.activeEmergency;
    final isPendingLoading =
        (pendingEmergenciesAsync.isLoading && pendingEmergencies.isEmpty) ||
            emergencyState.isLoading;

    final markers = <MapMarker>[
      technicianMarker(lat, lng, name: 'Tú'),
      ...pendingEmergencies.map(
        (e) => emergencyMarker(
          e.lat ?? AppConstants.defaultLat,
          e.lng ?? AppConstants.defaultLng,
        ),
      ),
    ];

    final horizontal = AppResponsive.horizontalPadding(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: _onNavTap,
        isTechnician: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.pageBackgroundGradient,
              ),
            ),
          ),
          // ── Content: spacer + profile card + map ──────────────────────
          Column(
            children: [
              SizedBox(height: 64 + topInset),
              if (_navIndex == 2)
                AppFadeSlideIn(
                  child: _buildProfileCard(
                    technicianName: user?.name ?? 'Tecnico',
                    specialty: TechnicianSpecialties.labelForCode(
                      user?.specialty,
                    ),
                    isApproved: user?.isApproved ?? false,
                    isAvailable: isAvailable,
                    rating: stats?.rating ?? user?.rating ?? 0.0,
                    totalServices:
                        stats?.totalServices ?? user?.totalServices ?? 0,
                    pendingCount: pendingEmergencies.length,
                  ),
                ),
              if (_navIndex == 2 && activeEmergency != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 12),
                  child: _ActiveServiceNotice(
                    emergency: activeEmergency,
                    onOpen: () => context.push(
                      AppRoutes.activeService,
                      extra: activeEmergency.id,
                    ),
                  ),
                ),
              Expanded(
                child: switch (_navIndex) {
                  0 => _buildTechnicianHistoryView(
                      technicianHistory,
                      activeEmergency: activeEmergency,
                    ),
                  1 => _buildRequestsView(
                      emergencies: pendingEmergencies,
                      activeEmergency: activeEmergency,
                      isAvailable: isAvailable,
                      isLoading: isPendingLoading,
                    ),
                  2 => _buildMapView(
                      lat: lat,
                      lng: lng,
                      markers: markers,
                      emergencies: pendingEmergencies,
                      isAvailable: isAvailable,
                      isLoading: isPendingLoading,
                    ),
                  3 => _buildTechnicianChatHistoryView(
                      technicianHistory,
                      activeEmergency: activeEmergency,
                    ),
                  _ => _buildMapView(
                      lat: lat,
                      lng: lng,
                      markers: markers,
                      emergencies: pendingEmergencies,
                      isAvailable: isAvailable,
                      isLoading: isPendingLoading,
                    ),
                },
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
                  height: 64 + topInset,
                  padding: EdgeInsets.only(top: topInset),
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
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
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
                        const AppLogo(height: 32, width: 132),
                        const Spacer(),
                        ChatNotificationBell(
                          onTap: _openNotifications,
                          iconColor: AppColors.secondary,
                        ),
                        const Gap(8),
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
          if (_bannerEmergencies.isNotEmpty)
            Positioned(
              top: 72 + topInset,
              left: horizontal,
              right: horizontal,
              child: _NewEmergencyBanner(
                emergencies: _bannerEmergencies,
                onOpen: _openBannerEmergency,
                onOpenList: _openRequestsTabFromBanner,
                onDismiss: () {
                  _bannerDismissTimer?.cancel();
                  setState(() => _bannerEmergencies = const []);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

// ── Emergency card for SERVICIOS tab ─────────────────────────────────────────

class _ActiveServiceNotice extends StatelessWidget {
  final Emergency emergency;
  final VoidCallback onOpen;

  const _ActiveServiceNotice({
    required this.emergency,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final serviceName = emergency.pricingServiceName ??
        emergency.aiEmergencyType ??
        emergency.clasificacionIa ??
        'Servicio activo';
    final driverName = emergency.driverName ?? 'Conductor';
    final address = emergency.direccion?.trim().isNotEmpty == true
        ? emergency.direccion!
        : 'Ubicacion del conductor';

    return AnimatedPressable(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(22),
      pressedScale: 0.985,
      hoverScale: 1.006,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.82),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.24),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Atendiendo ahora',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const Gap(8),
                      const Icon(
                        Icons.circle,
                        color: AppColors.success,
                        size: 9,
                      ),
                    ],
                  ),
                  const Gap(8),
                  Text(
                    serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const Gap(3),
                  Text(
                    '$driverName - $address',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(10),
            FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Ver'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicianHistoryCard extends StatelessWidget {
  final Emergency emergency;

  const _TechnicianHistoryCard({required this.emergency});

  @override
  Widget build(BuildContext context) {
    final serviceName = emergency.pricingServiceName ??
        emergency.aiEmergencyType ??
        emergency.clasificacionIa ??
        'Emergencia';
    final status = _statusLabel(emergency);
    final statusColor = _statusColor(emergency);
    final amount = emergency.protectedTotal ?? emergency.estimatedTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
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
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _statusIcon(emergency),
                  color: statusColor,
                  size: 21,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      emergency.driverName ?? 'Conductor',
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
              const Gap(8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AppColors.secondary,
              ),
              const Gap(6),
              Text(
                AppHelpers.formatDate(emergency.fecha),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Icon(
                PaymentMethods.icon(emergency.paymentMethod),
                size: 15,
                color: AppColors.secondary,
              ),
              const Gap(5),
              Text(
                PaymentMethods.label(emergency.paymentMethod),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const Gap(12),
              Text(
                amount == null
                    ? 'Revision pendiente'
                    : AppHelpers.formatCurrency(amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Gap(10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: AppColors.secondary,
              ),
              const Gap(6),
              Expanded(
                child: Text(
                  emergency.direccion?.trim().isNotEmpty == true
                      ? emergency.direccion!
                      : 'Ubicacion del conductor',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusLabel(Emergency emergency) {
    if (emergency.estado == AppConstants.statusCompleted ||
        emergency.asignacionEstado == AppConstants.assignFinished) {
      return 'Completada';
    }
    if (emergency.estado == AppConstants.statusCancelled) return 'Cancelada';
    if (emergency.asignacionEstado == AppConstants.assignRejected) {
      return 'Rechazada';
    }
    if (emergency.asignacionEstado == AppConstants.assignAttending) {
      return 'Atendiendo';
    }
    if (emergency.asignacionEstado == AppConstants.assignEnRoute) {
      return 'En ruta';
    }
    if (emergency.asignacionEstado == AppConstants.assignAccepted ||
        emergency.estado == AppConstants.statusInProgress) {
      return 'Aceptada';
    }
    return 'Pendiente';
  }

  static Color _statusColor(Emergency emergency) {
    if (emergency.estado == AppConstants.statusCompleted ||
        emergency.asignacionEstado == AppConstants.assignFinished) {
      return AppColors.success;
    }
    if (emergency.estado == AppConstants.statusCancelled ||
        emergency.asignacionEstado == AppConstants.assignRejected) {
      return AppColors.secondary;
    }
    if (emergency.asignacionEstado == AppConstants.assignAttending) {
      return AppColors.warning;
    }
    return AppColors.primary;
  }

  static IconData _statusIcon(Emergency emergency) {
    if (emergency.estado == AppConstants.statusCompleted ||
        emergency.asignacionEstado == AppConstants.assignFinished) {
      return Icons.check_circle_rounded;
    }
    if (emergency.estado == AppConstants.statusCancelled ||
        emergency.asignacionEstado == AppConstants.assignRejected) {
      return Icons.block_rounded;
    }
    if (emergency.asignacionEstado == AppConstants.assignAttending) {
      return Icons.build_rounded;
    }
    return Icons.assignment_rounded;
  }
}

class _TechnicianChatHistoryCard extends StatelessWidget {
  final Emergency emergency;
  final VoidCallback onTap;

  const _TechnicianChatHistoryCard({
    required this.emergency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final closed = emergency.estado == AppConstants.statusCompleted ||
        emergency.estado == AppConstants.statusCancelled ||
        emergency.asignacionEstado == AppConstants.assignFinished ||
        emergency.asignacionEstado == AppConstants.assignRejected;
    final serviceName = emergency.pricingServiceName ??
        emergency.aiEmergencyType ??
        emergency.clasificacionIa ??
        'Servicio';

    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      pressedScale: 0.975,
      hoverScale: 1.008,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              UserAvatar(
                name: emergency.driverName ?? 'Conductor',
                radius: 24,
                backgroundColor: AppColors.surfaceContainerHigh,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emergency.driverName ?? 'Conductor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Gap(3),
                    Text(
                      closed
                          ? '$serviceName - solo lectura'
                          : '$serviceName - chat activo',
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
              const Gap(8),
              Icon(
                closed ? Icons.lock_outline_rounded : Icons.chat_bubble,
                size: 20,
                color: closed ? AppColors.secondary : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  final String message;
  final String detail;
  final VoidCallback onRetry;

  const _HistoryErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.secondary,
              size: 34,
            ),
            const Gap(10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const Gap(6),
            Text(
              detail,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(14),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTechnicianHistory extends StatelessWidget {
  const _EmptyTechnicianHistory();

  @override
  Widget build(BuildContext context) {
    return const _EmptyPanel(
      icon: Icons.history_rounded,
      title: 'Aun no tienes historial',
      message: 'Cuando aceptes o completes solicitudes apareceran aqui.',
    );
  }
}

class _EmptyTechnicianChats extends StatelessWidget {
  const _EmptyTechnicianChats();

  @override
  Widget build(BuildContext context) {
    return const _EmptyPanel(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Sin chats todavia',
      message: 'Las conversaciones de servicios aceptados se guardaran aqui.',
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.secondary),
          const Gap(10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const Gap(4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewEmergencyBanner extends StatelessWidget {
  final List<Emergency> emergencies;
  final VoidCallback onOpen;
  final VoidCallback onOpenList;
  final VoidCallback onDismiss;

  const _NewEmergencyBanner({
    required this.emergencies,
    required this.onOpen,
    required this.onOpenList,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final first = emergencies.first;
    final count = emergencies.length;
    final serviceName = first.pricingServiceName ??
        first.aiEmergencyType ??
        first.clasificacionIa ??
        'Emergencia';
    final address = first.direccion?.trim().isNotEmpty == true
        ? first.direccion!.trim()
        : 'Ubicacion del conductor';
    final title = count == 1 ? 'Nueva solicitud' : '$count nuevas solicitudes';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.16),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    '$serviceName - $address',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(8),
            IconButton(
              tooltip: 'Ver lista',
              onPressed: onOpenList,
              icon: const Icon(Icons.list_alt_rounded),
              color: AppColors.secondary,
            ),
            FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(56, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Ver'),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyRequestCard extends StatelessWidget {
  final Emergency emergency;
  final bool canAccept;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onAccept;

  const _EmergencyRequestCard({
    required this.emergency,
    required this.canAccept,
    required this.isLoading,
    required this.onTap,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final serviceName = emergency.pricingServiceName ??
        emergency.aiEmergencyType ??
        emergency.clasificacionIa ??
        'Emergencia';
    final amount = emergency.protectedTotal ?? emergency.estimatedTotal;
    final amountText = amount == null
        ? 'Revision pendiente'
        : AppHelpers.formatCurrency(amount);
    final address = emergency.direccion?.trim().isNotEmpty == true
        ? emergency.direccion!
        : 'Ubicacion del conductor';
    final description = emergency.aiTechnicianSummary?.trim().isNotEmpty == true
        ? emergency.aiTechnicianSummary!.trim()
        : emergency.descripcion.trim();
    final hasOffer = emergency.hasMyOffer;
    final offeredAmount = emergency.myOfferedAmount;

    return AnimatedPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      pressedScale: 0.985,
      hoverScale: 1.006,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.05),
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
                      color: AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.car_repair_rounded,
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
                          serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          emergency.driverName ?? 'Conductor',
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
                  const Gap(8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amountText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color:
                              hasOffer ? AppColors.warning : AppColors.primary,
                        ),
                      ),
                      if (hasOffer) ...[
                        const Gap(6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningContainer,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  AppColors.warning.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Text(
                            'Oferta enviada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const Gap(12),
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurface,
                    height: 1.35,
                  ),
                ),
                const Gap(10),
              ],
              _RequestMetaLine(
                icon: PaymentMethods.icon(emergency.paymentMethod),
                text: 'Pago: ${PaymentMethods.label(emergency.paymentMethod)}',
              ),
              const Gap(8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasOffer) ...[
                const Gap(12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_offer_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          offeredAmount == null
                              ? 'Oferta enviada. Puedes editarla antes de que el conductor elija.'
                              : 'Oferta enviada por ${AppHelpers.formatCurrency(offeredAmount)}. Puedes ajustarla si lo necesitas.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Gap(14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTap,
                      child: const Text('Ver detalle'),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: FilledButton(
                      onPressed: !canAccept || isLoading ? null : onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            hasOffer ? AppColors.warning : AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        hasOffer ? 'Oferta enviada' : 'Ofertar',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyEmergencyRequests extends StatelessWidget {
  const _EmptyEmergencyRequests();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusCard),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 34,
            color: AppColors.secondary,
          ),
          Gap(10),
          Text(
            'No hay solicitudes activas',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          Gap(4),
          Text(
            'Cuando un conductor reporte una emergencia aparecera aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RequestMetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RequestMetaLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const Gap(6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

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
        borderRadius: BorderRadius.circular(14),
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
                  style: TextStyle(
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
      child: AnimatedPressable(
        onTap: showProgress ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        pressedScale: 0.92,
        hoverScale: 1.02,
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.30),
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
