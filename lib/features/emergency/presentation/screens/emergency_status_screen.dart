import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
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
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text(e.toString())),
      ),
      data: (emergency) => _StatusBody(emergency: emergency),
    );
  }
}

class _StatusBody extends ConsumerWidget {
  final Emergency emergency;

  const _StatusBody({required this.emergency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lat = emergency.lat ?? AppConstants.defaultLat;
    final lng = emergency.lng ?? AppConstants.defaultLng;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
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
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top),
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
                        GestureDetector(
                          onTap: () => context.go(AppRoutes.driverHome),
                          child: const Icon(Icons.menu,
                              color: AppColors.onSurface),
                        ),
                        const Spacer(),
                        const Text(
                          'Solicitudes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          child: const Icon(Icons.person,
                              size: 18, color: AppColors.secondary),
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
            top: 64 + MediaQuery.of(context).padding.top,
            bottom: 80 + MediaQuery.of(context).padding.bottom,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  // ETA Hero
                  _ETAHero(emergency: emergency),
                  const Gap(24),

                  // Live Map
                  _LiveMap(lat: lat, lng: lng),
                  const Gap(24),

                  // Technician Card
                  if (emergency.hasTechnician)
                    _TechnicianCard(emergency: emergency)
                  else
                    _SearchingCard(),
                  const Gap(24),

                  // Timeline
                  _TimelineStepper(emergency: emergency),
                ],
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
                      context.push(AppRoutes.driverChat,
                          extra: emergency.id);
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

class _ETAHero extends StatelessWidget {
  final Emergency emergency;

  const _ETAHero({required this.emergency});

  @override
  Widget build(BuildContext context) {
    final (etaText, subtitle) = _getETAInfo(emergency.asignacionEstado);

    return Column(
      children: [
        Text(
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
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -2,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  (String, String) _getETAInfo(String? status) {
    switch (status) {
      case AppConstants.assignAccepted:
        return ('8 mins', 'El tecnico esta preparandose');
      case AppConstants.assignEnRoute:
        return ('8 mins', 'El tecnico esta en camino a tu ubicacion');
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

  const _LiveMap({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 256,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                        child: Icon(Icons.circle,
                            color: Colors.white, size: 12),
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
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
          ),
          // Address badge
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(8),
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
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'AV. DANIEL LEON BORJA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
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
                    color: Colors.black.withOpacity(0.15),
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

  const _TechnicianCard({required this.emergency});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withOpacity(0.04),
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
                          AppHelpers.getInitials(
                              emergency.tecnicoNombre ?? 'T'),
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
                            border:
                                Border.all(color: Colors.white, width: 2),
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
                          emergency.tecnicoNombre ?? 'Tecnico',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: Color(0xFFFACC15)),
                            const Gap(4),
                            const Text(
                              '4.9',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              ' \u2022 ',
                              style: TextStyle(
                                color:
                                    AppColors.secondary.withOpacity(0.5),
                              ),
                            ),
                            Text(
                              emergency.clasificacionIa ??
                                  'Especialista',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ETA badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me,
                            size: 14, color: AppColors.primary),
                        const Gap(4),
                        Text(
                          'ETA',
                          style: TextStyle(
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
                      onTap: () {},
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
                onPressed: () {},
                child: Text(
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

class _SearchingCard extends StatefulWidget {
  @override
  State<_SearchingCard> createState() => _SearchingCardState();
}

class _SearchingCardState extends State<_SearchingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
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
            child: const Icon(Icons.sync,
                color: AppColors.primary, size: 32),
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
          Text(
            'Estamos buscando el tecnico mas cercano',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondary,
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
    final currentStatus = emergency.asignacionEstado ?? '';
    final steps = [
      _TimelineStep(
        title: 'Solicitud enviada',
        subtitle: 'Riobamba Central \u2022 ${AppHelpers.formatTime(emergency.fecha)}',
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
        children: steps
            .map((step) => _TimelineStepWidget(step: step))
            .toList(),
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
                    ? const Icon(Icons.check,
                        size: 14, color: Colors.white)
                    : step.status == _StepStatus.active
                        ? Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
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
                            ? AppColors.secondary.withOpacity(0.5)
                            : AppColors.onSurface,
                  ),
                ),
                Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: step.status == _StepStatus.pending
                        ? AppColors.secondary.withOpacity(0.5)
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
