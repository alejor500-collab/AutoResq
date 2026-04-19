import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

class AppMapWidget extends StatelessWidget {
  final double lat;
  final double lng;
  final double zoom;
  final List<MapMarker> markers;
  final MapController? controller;
  final bool interactiveMap;

  const AppMapWidget({
    super.key,
    this.lat = AppConstants.defaultLat,
    this.lng = AppConstants.defaultLng,
    this.zoom = AppConstants.defaultZoom,
    this.markers = const [],
    this.controller,
    this.interactiveMap = true,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: LatLng(lat, lng),
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactiveMap
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConstants.osmTileUrl,
          userAgentPackageName: 'com.autoresq.app',
          tileProvider: NetworkTileProvider(),
        ),
        MarkerLayer(
          markers: markers.map((m) => _buildMarker(m)).toList(),
        ),
      ],
    );
  }

  Marker _buildMarker(MapMarker m) {
    return Marker(
      point: LatLng(m.lat, m.lng),
      width: 44,
      height: 54,
      child: _MarkerWidget(
        color: m.color,
        icon: m.icon,
        label: m.label,
      ),
    );
  }
}

class MapMarker {
  final double lat;
  final double lng;
  final Color color;
  final IconData icon;
  final String? label;

  const MapMarker({
    required this.lat,
    required this.lng,
    required this.color,
    required this.icon,
    this.label,
  });
}

class _MarkerWidget extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String? label;

  const _MarkerWidget({
    required this.color,
    required this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        // Pin tail
        Container(
          width: 2,
          height: 10,
          color: color,
        ),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// ─── Driver Marker ────────────────────────────────────────────────────────────
MapMarker driverMarker(double lat, double lng) => MapMarker(
      lat: lat,
      lng: lng,
      color: AppColors.driverMarker,
      icon: Icons.person,
      label: 'Tú',
    );

// ─── Technician Marker ────────────────────────────────────────────────────────
MapMarker technicianMarker(double lat, double lng, {String? name}) =>
    MapMarker(
      lat: lat,
      lng: lng,
      color: AppColors.technicianMarker,
      icon: Icons.build,
      label: name,
    );

// ─── Emergency Marker ─────────────────────────────────────────────────────────
MapMarker emergencyMarker(double lat, double lng) => MapMarker(
      lat: lat,
      lng: lng,
      color: AppColors.emergencyMarker,
      icon: Icons.warning_amber_rounded,
    );
