import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/auth_provider.dart';

class RatingNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseClient _client;
  final Ref _ref;

  RatingNotifier(this._client, this._ref) : super(const AsyncValue.data(null));

  Future<bool> submitRating({
    required String emergenciaId,
    required String calificadoId,
    required int puntuacion,
    String? comentario,
  }) async {
    final user = _ref.read(authNotifierProvider).value;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      await _client.from(AppConstants.tableCalificaciones).insert({
        'emergencia_id': emergenciaId,
        'calificador_id': user.id,
        'calificado_id': calificadoId,
        'puntuacion': puntuacion,
        if (comentario != null) 'comentario': comentario,
      });

      // The trigger `actualizar_calificacion_promedio` handles
      // updating the technician's average rating automatically.

      state = const AsyncValue.data(null);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }
}

final ratingNotifierProvider =
    StateNotifierProvider<RatingNotifier, AsyncValue<void>>((ref) {
  return RatingNotifier(ref.read(supabaseClientProvider), ref);
});
