import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/location_entity.dart';

Future<LocationEntity?> showLocationPickerSheet(
  BuildContext context, {
  LocationEntity? initialLocation,
  String title = 'Seleccionar ubicacion',
}) {
  return Navigator.of(context).push<LocationEntity>(
    PageRouteBuilder<LocationEntity>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      pageBuilder: (_, __, ___) => _LocationPickerScreen(
        initialLocation: initialLocation,
        title: title,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _LocationPickerScreen extends StatefulWidget {
  final LocationEntity? initialLocation;
  final String title;

  const _LocationPickerScreen({
    required this.initialLocation,
    required this.title,
  });

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  final _mapController = MapController();
  late LatLng _selected;
  String? _address;
  bool _isResolving = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(
      widget.initialLocation?.lat ?? AppConstants.defaultLat,
      widget.initialLocation?.lng ?? AppConstants.defaultLng,
    );
    _address = widget.initialLocation?.address;
    _resolveAddress();
  }

  Future<void> _resolveAddress() async {
    setState(() => _isResolving = true);
    try {
      final address = await DioClient().reverseGeocode(
        _selected.latitude,
        _selected.longitude,
      );
      if (mounted) setState(() => _address = address);
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Activa el servicio de ubicacion');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Permiso de ubicacion denegado');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final next = LatLng(position.latitude, position.longitude);
      setState(() => _selected = next);
      _mapController.move(next, 16);
      await _resolveAddress();
    } catch (_) {
      _showError('No se pudo obtener tu ubicacion actual');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _confirm() {
    Navigator.pop(
      context,
      LocationEntity(
        lat: _selected.latitude,
        lng: _selected.longitude,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final horizontalPadding = isWide ? 32.0 : 18.0;

              final mapCard = _PickerSurface(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _selected,
                              initialZoom:
                                  widget.initialLocation == null ? 7 : 15,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                              ),
                              onTap: (_, point) {
                                setState(() => _selected = point);
                                _resolveAddress();
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: AppConstants.osmTileUrl,
                                userAgentPackageName: 'com.autoresq.app',
                                tileProvider: NetworkTileProvider(),
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selected,
                                    width: 52,
                                    height: 52,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.96, end: 1),
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      curve: Curves.easeOutBack,
                                      builder: (context, scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 14,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.location_pin,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 80,
                        top: 16,
                        child: _MapInstructionBanner(
                          text: 'Toca el mapa para ajustar el punto exacto.',
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'location-picker-current',
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          onPressed: _isLocating ? null : _useCurrentLocation,
                          child: _isLocating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final summaryCard = _PickerSurface(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: _SelectedLocationSummary(
                    address: _isResolving
                        ? 'Resolviendo direccion...'
                        : (_address ?? 'Ubicacion seleccionada en Ecuador'),
                    isResolving: _isResolving,
                    onConfirm: _confirm,
                  ),
                ),
              );

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      18 + bottomInset,
                    ),
                    child: Column(
                      children: [
                        _PickerHeader(
                          title: widget.title,
                          onClose: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(flex: 7, child: mapCard),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 4,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: summaryCard,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Expanded(child: mapCard),
                                    const SizedBox(height: 18),
                                    summaryCard,
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _PickerHeader({
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return _PickerSurface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _PickerSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _PickerSurface({
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = padding == null ? child : Padding(padding: padding!, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _MapInstructionBanner extends StatelessWidget {
  final String text;

  const _MapInstructionBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.touch_app_outlined,
              size: 17,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedLocationSummary extends StatelessWidget {
  final String address;
  final bool isResolving;
  final VoidCallback onConfirm;

  const _SelectedLocationSummary({
    required this.address,
    required this.isResolving,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isResolving ? Icons.sync_rounded : Icons.location_on_outlined,
                size: 18,
                color: isResolving ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ubicacion seleccionada',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Text(
              address,
              key: ValueKey(address),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadiusButton,
                  ),
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded),
                    SizedBox(width: 8),
                    Text('Usar esta ubicacion'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
