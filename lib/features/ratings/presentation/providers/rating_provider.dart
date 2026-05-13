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
    required String raterRole,
    String? comentario,
    bool refreshCurrentUser = true,
  }) async {
    final user = _ref.read(authNotifierProvider).value ??
        _ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      await _client.from(AppConstants.tableCalificaciones).insert({
        'emergencia_id': emergenciaId,
        'calificador_id': user.id,
        'calificado_id': calificadoId,
        'puntuacion': puntuacion,
        'rater_role': raterRole,
        if (comentario != null) 'comentario': comentario,
      });

      await _recalculateStats(calificadoId);
      await _recalculateStats(user.id);
      if (refreshCurrentUser) {
        final freshUser =
            await _ref.read(authNotifierProvider.notifier).reloadCurrentUser();
        _ref.read(currentUserProvider.notifier).state = freshUser;
      }

      state = const AsyncValue.data(null);
      return true;
    } on PostgrestException catch (e, s) {
      if (e.code == '23505' ||
          e.message.toLowerCase().contains('duplicate key')) {
        await _recalculateStats(calificadoId);
        await _recalculateStats(user.id);
        if (refreshCurrentUser) {
          final freshUser =
              await _ref.read(authNotifierProvider.notifier).reloadCurrentUser();
          _ref.read(currentUserProvider.notifier).state = freshUser;
        }
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(e.message, s);
      return false;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<void> _recalculateStats(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _client.rpc(
        'recalculate_user_rating_stats',
        params: {'p_user_id': userId},
      );
    } catch (_) {
      // The SQL migration adds this RPC. Existing triggers still handle inserts.
    }
  }
}

final ratingNotifierProvider =
    StateNotifierProvider<RatingNotifier, AsyncValue<void>>((ref) {
  return RatingNotifier(ref.read(supabaseClientProvider), ref);
});
