import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../map/presentation/widgets/map_widget.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';
import 'incoming_request_sheet.dart';

class TechnicianHomeScreen extends ConsumerStatefulWidget {
  const TechnicianHomeScreen({super.key});

  @override
  ConsumerState<TechnicianHomeScreen> createState() =>
      _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState
    extends ConsumerState<TechnicianHomeScreen> {
  final _mapController = MapController();
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(mapNotifierProvider.notifier).getCurrentLocation();
      final mapState = ref.read(mapNotifierProvider);
      if (mapState.currentLocation != null) {
        ref.read(emergencyNotifierProvider.notifier).loadPendingEmergencies();
      }
    });
  }

  void _toggleAvailability(bool val) {
    setState(() => _isAvailable = val);
    // TODO: Update availability in Supabase
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapNotifierProvider);
    final emergencyState = ref.watch(emergencyNotifierProvider);
    final user = ref.watch(authNotifierProvider).value;

    final lat = mapState.currentLocation?.lat ?? AppConstants.defaultLat;
    final lng = mapState.currentLocation?.lng ?? AppConstants.defaultLng;

    final markers = <MapMarker>[
      technicianMarker(lat, lng, name: 'Tú'),
      ...emergencyState.emergencies.map(
          (e) => emergencyMarker(e.lat ?? AppConstants.defaultLat, e.lng ?? AppConstants.defaultLng)),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ─── Map ──────────────────────────────────────────────────────
          Positioned.fill(
            child: AppMapWidget(
              lat: lat,
              lng: lng,
              zoom: 13.5,
              controller: _mapController,
              markers: markers,
            ),
          ),

          // ─── Top Bar ──────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.build,
                            color: AppColors.secondary, size: 18),
                        const Gap(6),
                        const Text(
                          'Modo Técnico',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.profile),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: UserAvatar(
                        imageUrl: user?.avatarUrl,
                        name: user?.name ?? 'Técnico',
                        radius: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Bottom Panel ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Gap(16),
                  // Availability toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isAvailable
                          ? AppColors.success.withOpacity(0.08)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isAvailable
                            ? AppColors.success.withOpacity(0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _isAvailable
                                ? AppColors.success
                                : AppColors.textHint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Gap(10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAvailable
                                  ? 'Disponible'
                                  : 'No disponible',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _isAvailable
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _isAvailable
                                  ? 'Recibiendo solicitudes'
                                  : 'No recibes solicitudes',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Switch(
                          value: _isAvailable,
                          onChanged: _toggleAvailability,
                          activeColor: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                  const Gap(12),

                  // Nearby emergencies
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Emergencias cercanas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (emergencyState.isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary),
                        )
                      else
                        Text(
                          '${emergencyState.emergencies.length} activas',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  const Gap(8),
                  if (emergencyState.emergencies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No hay emergencias cercanas',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    )
                  else
                    ...emergencyState.emergencies
                        .take(3)
                        .map((e) => _NearbyEmergencyCard(
                              emergency: e,
                              onTap: () => _showRequestSheet(e),
                            )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestSheet(Emergency emergency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomingRequestSheet(emergency: emergency),
    );
  }
}

class _NearbyEmergencyCard extends StatelessWidget {
  final Emergency emergency;
  final VoidCallback onTap;

  const _NearbyEmergencyCard(
      {required this.emergency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 18),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emergency.descripcion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    emergency.direccion ??
                        '${(emergency.lat ?? 0).toStringAsFixed(4)}, ${(emergency.lng ?? 0).toStringAsFixed(4)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Gap(8),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
