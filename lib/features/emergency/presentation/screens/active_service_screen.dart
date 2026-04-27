import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../map/presentation/widgets/map_widget.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';

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
  Timer? _attendingTimer;
  int _attendingSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.emergency.asignacionEstado == AppConstants.assignAttending) {
        ref.read(_activeSubstateProvider.notifier).state =
            AppConstants.assignAttending;
        _startAttendingTimer();
      }
    });
  }

  void _startAttendingTimer() {
    _attendingTimer?.cancel();
    _attendingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _attendingSeconds++);
    });
  }

  String _formatElapsed() {
    final m = _attendingSeconds ~/ 60;
    final s = _attendingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _onHeLlegado() async {
    final asignacionId = widget.emergency.asignacionId;
    if (asignacionId != null && asignacionId.isNotEmpty) {
      try {
        await ref
            .read(supabaseClientProvider)
            .from(AppConstants.tableAsignaciones)
            .update({'estado': AppConstants.assignAttending})
            .eq('id', asignacionId);
      } catch (_) {}
    }
    if (!mounted) return;
    ref.read(_activeSubstateProvider.notifier).state =
        AppConstants.assignAttending;
    _startAttendingTimer();
  }

  @override
  void dispose() {
    _attendingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final substate = ref.watch(_activeSubstateProvider);
    final emergency = widget.emergency;
    final lat = emergency.lat ?? AppConstants.defaultLat;
    final lng = emergency.lng ?? AppConstants.defaultLng;
    final isEnRoute = substate == AppConstants.assignEnRoute;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ─── Mapa ────────────────────────────────────────────────────
          Expanded(
            flex: isEnRoute ? 3 : 2,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AppMapWidget(
                    lat: lat,
                    lng: lng,
                    zoom: 15,
                    markers: [emergencyMarker(lat, lng)],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        // Botón atrás
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          shadowColor: Colors.black12,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => context.pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(Icons.arrow_back_ios_new,
                                  size: 18, color: AppColors.onSurface),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Chip de estado flotante centrado
                        _StatusFloatingChip(
                          label: isEnRoute ? 'EN RUTA' : 'ATENDIENDO',
                          color: isEnRoute
                              ? const Color(0xFF1E88E5)
                              : const Color(0xFFF59E0B),
                          icon: isEnRoute
                              ? Icons.navigation_rounded
                              : Icons.build_rounded,
                        ),
                        const Spacer(),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Tarjeta inferior ─────────────────────────────────────────
          Expanded(
            flex: isEnRoute ? 2 : 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: isEnRoute
                  ? _EnRoutePanel(
                      emergency: emergency,
                      onHeLlegado: _onHeLlegado,
                    )
                  : _AttendingPanel(
                      emergency: emergency,
                      elapsed: _formatElapsed(),
                    ),
            ),
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

  const _EnRoutePanel({
    required this.emergency,
    required this.onHeLlegado,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                letterSpacing: -0.5,
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

          // Llamar + Chat
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Llamar',
                  variant: AppButtonVariant.outline,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18,
                      color: AppColors.onSurface),
                  onPressed: () {},
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
            label: '📍 He llegado',
            onPressed: onHeLlegado,
          ),
        ],
      ),
    );
  }
}

// ─── Panel ATENDIENDO ─────────────────────────────────────────────────────────

class _AttendingPanel extends StatelessWidget {
  final Emergency emergency;
  final String elapsed;

  const _AttendingPanel({
    required this.emergency,
    required this.elapsed,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
          const Gap(24),

          // Contador
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.10),
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusCard),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.35),
                ),
              ),
              child: Text(
                elapsed,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF59E0B),
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
            label: '✅ Finalizar Servicio',
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
              },
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
            color: color.withOpacity(0.40),
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
