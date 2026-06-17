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
  final List<MapPolyline> polylines;
  final MapController? controller;
  final bool interactiveMap;
  final bool fitBounds;

  const AppMapWidget({
    super.key,
    this.lat = AppConstants.defaultLat,
    this.lng = AppConstants.defaultLng,
    this.zoom = AppConstants.defaultZoom,
    this.markers = const [],
    this.polylines = const [],
    this.controller,
    this.interactiveMap = true,
    this.fitBounds = false,
  });

  @override
  Widget build(BuildContext context) {
    final boundsPoints = <LatLng>[
      ...markers.map((marker) => LatLng(marker.lat, marker.lng)),
      ...polylines.expand((polyline) => polyline.points),
    ];

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: LatLng(lat, lng),
        initialZoom: zoom,
        initialCameraFit: fitBounds && boundsPoints.length >= 2
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(boundsPoints),
                padding: const EdgeInsets.all(56),
              )
            : null,
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
        if (polylines.isNotEmpty)
          PolylineLayer(
            polylines: polylines
                .where((polyline) => polyline.points.length >= 2)
                .map(
                  (polyline) => Polyline(
                    points: polyline.points,
                    color: polyline.color,
                    strokeWidth: polyline.strokeWidth,
                  ),
                )
                .toList(),
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

class MapPolyline {
  final List<LatLng> points;
  final Color color;
  final double strokeWidth;

  const MapPolyline({
    required this.points,
    required this.color,
    this.strokeWidth = 3,
  });
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
                color: color.withValues(alpha: 0.4),
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
