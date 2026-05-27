import 'technician_specialties.dart';

class EmergencyDistanceBand {
  final int rank;
  final String label;
  final double maxKm;

  const EmergencyDistanceBand({
    required this.rank,
    required this.label,
    required this.maxKm,
  });

  bool get isNearby => rank <= 1;
}

abstract class EmergencyMatchPolicy {
  static const priority = EmergencyDistanceBand(
    rank: 0,
    label: 'Técnico cercano disponible',
    maxKm: 5,
  );
  static const expanded = EmergencyDistanceBand(
    rank: 1,
    label: 'Disponible en zona ampliada',
    maxKm: 10,
  );
  static const backup = EmergencyDistanceBand(
    rank: 2,
    label: 'Respaldo',
    maxKm: 15,
  );
  static const towPriority = EmergencyDistanceBand(
    rank: 0,
    label: 'Grúa cercana disponible',
    maxKm: 10,
  );
  static const towExpanded = EmergencyDistanceBand(
    rank: 1,
    label: 'Grúa disponible en zona ampliada',
    maxKm: 20,
  );
  static const unknown = EmergencyDistanceBand(
    rank: 2,
    label: 'Ubicación por confirmar',
    maxKm: 0,
  );

  static bool isTowCategory(String? emergencyType) {
    return TechnicianSpecialties.specialtyCodesForEmergencyType(emergencyType)
        .contains(TechnicianSpecialties.towTruck);
  }

  static EmergencyDistanceBand? bandFor({
    required String? emergencyType,
    required double? distanceKm,
  }) {
    if (distanceKm == null) return unknown;
    if (distanceKm < 0) return null;

    if (isTowCategory(emergencyType)) {
      if (distanceKm <= towPriority.maxKm) return towPriority;
      if (distanceKm <= towExpanded.maxKm) return towExpanded;
      return null;
    }

    if (distanceKm <= priority.maxKm) return priority;
    if (distanceKm <= expanded.maxKm) return expanded;
    if (distanceKm <= backup.maxKm) return backup;
    return null;
  }

  static List<T> visibleRanked<T>({
    required Iterable<T> items,
    required String? emergencyType,
    required double? Function(T item) distanceKm,
    required double Function(T item) rating,
  }) {
    final annotated = <({T item, EmergencyDistanceBand band, double? distance})>[];
    for (final item in items) {
      final distance = distanceKm(item);
      final band = bandFor(emergencyType: emergencyType, distanceKm: distance);
      if (band == null) continue;
      annotated.add((item: item, band: band, distance: distance));
    }

    final hasNearby = annotated.any((entry) => entry.band.isNearby);
    final visible = annotated
        .where((entry) => entry.band.isNearby || !hasNearby)
        .toList();

    visible.sort((a, b) {
      final bandCompare = a.band.rank.compareTo(b.band.rank);
      if (bandCompare != 0) return bandCompare;

      final ratingCompare = rating(b.item).compareTo(rating(a.item));
      if (ratingCompare != 0) return ratingCompare;

      final aDistance = a.distance ?? double.infinity;
      final bDistance = b.distance ?? double.infinity;
      return aDistance.compareTo(bDistance);
    });

    return visible.map((entry) => entry.item).toList();
  }
}
