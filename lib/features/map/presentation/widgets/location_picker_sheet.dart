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
  return showModalBottomSheet<LocationEntity>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LocationPickerSheet(
      initialLocation: initialLocation,
      title: title,
    ),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  final LocationEntity? initialLocation;
  final String title;

  const _LocationPickerSheet({
    required this.initialLocation,
    required this.title,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
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
    return SafeArea(
      top: false,
      child: Container(
        height: mediaQuery.size.height * 0.9,
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            height: 1.15,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selected,
                    initialZoom: widget.initialLocation == null ? 7 : 15,
                    onTap: (_, point) {
                      setState(() => _selected = point);
                      _resolveAddress();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: AppConstants.osmTileUrl,
                      userAgentPackageName: 'com.autoresq.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selected,
                          width: 52,
                          height: 52,
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
                                  color: AppColors.primary.withValues(alpha: 0.35),
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
                      ],
                    ),
                  ],
                ),
                  Positioned(
                    left: 16,
                    right: 78,
                    top: 14,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: _SelectedLocationSummary(
                address: _isResolving
                    ? 'Resolviendo direccion...'
                    : (_address ?? 'Ubicacion seleccionada en Ecuador'),
                isResolving: _isResolving,
                onConfirm: _confirm,
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            children: [
              Icon(
                isResolving
                    ? Icons.sync_rounded
                    : Icons.location_on_outlined,
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
          Text(
            address,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
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
