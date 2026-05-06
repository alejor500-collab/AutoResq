import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import 'auth_provider.dart';

class TechnicianStats {
  final double rating;
  final int totalServices;
  final bool isAvailable;

  const TechnicianStats({
    required this.rating,
    required this.totalServices,
    required this.isAvailable,
  });

  const TechnicianStats.empty()
      : rating = 0,
        totalServices = 0,
        isAvailable = false;

  factory TechnicianStats.fromJson(Map<String, dynamic> json) {
    return TechnicianStats(
      rating: (json['calificacion_promedio'] as num?)?.toDouble() ?? 0,
      totalServices: (json['total_servicios'] as num?)?.toInt() ?? 0,
      isAvailable: json['disponible'] as bool? ?? false,
    );
  }
}

final technicianStatsProvider =
    StreamProvider.autoDispose.family<TechnicianStats, String>((ref, userId) {
  if (userId.isEmpty) {
    return Stream.value(const TechnicianStats.empty());
  }

  final client = ref.read(supabaseClientProvider);
  return client
      .from(AppConstants.tableTecnicos)
      .stream(primaryKey: ['id'])
      .eq('usuario_id', userId)
      .map((rows) {
        if (rows.isEmpty) return const TechnicianStats.empty();
        return TechnicianStats.fromJson(rows.first);
      });
});
