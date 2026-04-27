import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/dio_client.dart';

// ─── Category enum ────────────────────────────────────────────────────────────
enum ServiceCategory {
  fuel,
  carRepair,
  tires,
  carWash,
  charging,
}

extension ServiceCategoryX on ServiceCategory {
  String get label {
    switch (this) {
      case ServiceCategory.fuel:
        return 'Gasolinera';
      case ServiceCategory.carRepair:
        return 'Mecánica';
      case ServiceCategory.tires:
        return 'Vulcanizadora';
      case ServiceCategory.carWash:
        return 'Lavadora';
      case ServiceCategory.charging:
        return 'Cargador EV';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceCategory.fuel:
        return Icons.local_gas_station_rounded;
      case ServiceCategory.carRepair:
        return Icons.build_rounded;
      case ServiceCategory.tires:
        return Icons.tire_repair_rounded;
      case ServiceCategory.carWash:
        return Icons.local_car_wash_rounded;
      case ServiceCategory.charging:
        return Icons.ev_station_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ServiceCategory.fuel:
        return const Color(0xFF1E88E5); // blue
      case ServiceCategory.carRepair:
        return AppColors.primary; // brand orange/red
      case ServiceCategory.tires:
        return const Color(0xFF43A047); // green
      case ServiceCategory.carWash:
        return const Color(0xFF00ACC1); // cyan
      case ServiceCategory.charging:
        return const Color(0xFF8E24AA); // purple
    }
  }

  /// Returns null if the OSM tags don't match this category.
  static ServiceCategory? fromTags(Map<String, dynamic> tags) {
    final amenity = tags['amenity']?.toString() ?? '';
    final shop = tags['shop']?.toString() ?? '';
    final service = tags['service']?.toString() ?? '';

    if (amenity == 'fuel') return ServiceCategory.fuel;
    if (amenity == 'charging_station') return ServiceCategory.charging;
    if (amenity == 'car_wash') return ServiceCategory.carWash;
    if (shop == 'car_repair' || amenity == 'car_repair') {
      return ServiceCategory.carRepair;
    }
    if (shop == 'tyres' || shop == 'tire' || service == 'tyres') {
      return ServiceCategory.tires;
    }
    return null;
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────
class NearbyService {
  final String name;
  final ServiceCategory category;
  final double lat;
  final double lng;
  final double distanceKm;

  const NearbyService({
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.distanceKm,
  });

  // Keep legacy `type` field for backward compat
  String get type => category.name;
  IconData get icon => category.icon;
  Color get color => category.color;
  String get typeLabel => category.label;

  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()}m';
    return '${distanceKm.toStringAsFixed(1)}km';
  }

  factory NearbyService.fromElement(
      Map<String, dynamic> e, double uLat, double uLng) {
    final tags = (e['tags'] as Map<String, dynamic>?) ?? {};
    final rawName =
        (tags['name'] ?? tags['operator'] ?? '').toString().trim();
    final eLat =
        ((e['lat'] ?? (e['center'] as Map?)?['lat'] ?? uLat) as num)
            .toDouble();
    final eLng =
        ((e['lon'] ?? (e['center'] as Map?)?['lon'] ?? uLng) as num)
            .toDouble();
    final cat = ServiceCategoryX.fromTags(tags) ?? ServiceCategory.carRepair;

    return NearbyService(
      name: rawName.isEmpty ? cat.label : rawName,
      category: cat,
      lat: eLat,
      lng: eLng,
      distanceKm: _haversineKm(uLat, uLng, eLat, eLng),
    );
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final nearbyServicesProvider = FutureProvider.autoDispose
    .family<List<NearbyService>, (double, double)>((ref, coords) async {
  final (lat, lng) = coords;
  final elements = await DioClient().queryNearbyServices(lat, lng);
  final services = elements
      .map((e) => NearbyService.fromElement(e, lat, lng))
      .where((s) => s.distanceKm <= 5.0)
      .toList()
    ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return services.take(30).toList();
});

// ─── Selected category filter ─────────────────────────────────────────────────
final selectedCategoryProvider =
    StateProvider.autoDispose<ServiceCategory?>((ref) => null);
