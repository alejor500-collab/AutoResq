import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/auth_provider.dart';

class AdminState {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> pendingTechnicians;
  final bool isLoading;
  final String? error;

  const AdminState({
    this.stats = const {},
    this.users = const [],
    this.pendingTechnicians = const [],
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? users,
    List<Map<String, dynamic>>? pendingTechnicians,
    bool? isLoading,
    String? error,
  }) {
    return AdminState(
      stats: stats ?? this.stats,
      users: users ?? this.users,
      pendingTechnicians: pendingTechnicians ?? this.pendingTechnicians,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  final SupabaseClient _client;

  AdminNotifier(this._client) : super(const AdminState());

  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true);
    try {
      final users = await _client
          .from(AppConstants.tableUsuarios)
          .select('rol, activo');

      final emergencies = await _client
          .from(AppConstants.tableEmergencias)
          .select('estado');

      final tecnicos = await _client
          .from(AppConstants.tableTecnicos)
          .select('estado_verificacion');

      final userList = users as List;
      final emList = emergencies as List;
      final techList = tecnicos as List;

      state = state.copyWith(
        isLoading: false,
        stats: {
          'total_users': userList.length,
          'total_technicians': techList.length,
          'pending_validations': techList
              .where((t) =>
                  t['estado_verificacion'] == AppConstants.verificationPending)
              .length,
          'active_emergencies': emList
              .where((e) =>
                  e['estado'] == AppConstants.statusPending ||
                  e['estado'] == AppConstants.statusInProgress)
              .length,
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _client
          .from(AppConstants.tableUsuarios)
          .select()
          .order('creado_en', ascending: false);

      state = state.copyWith(
        isLoading: false,
        users: List<Map<String, dynamic>>.from(data),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadPendingTechnicians() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _client
          .from(AppConstants.tableTecnicos)
          .select('*, usuarios(nombre, email, telefono)')
          .eq('estado_verificacion', AppConstants.verificationPending);

      state = state.copyWith(
        isLoading: false,
        pendingTechnicians: List<Map<String, dynamic>>.from(data),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> approveTechnician(String tecnicoId) async {
    try {
      final uid = _client.auth.currentUser?.id;
      await _client.from(AppConstants.tableTecnicos).update({
        'estado_verificacion': AppConstants.verificationApproved,
        'verificado_por': uid,
        'fecha_verificacion': DateTime.now().toIso8601String(),
      }).eq('id', tecnicoId);

      await loadPendingTechnicians();
      await loadStats();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectTechnician(String tecnicoId) async {
    try {
      final uid = _client.auth.currentUser?.id;
      await _client.from(AppConstants.tableTecnicos).update({
        'estado_verificacion': AppConstants.verificationRejected,
        'verificado_por': uid,
        'fecha_verificacion': DateTime.now().toIso8601String(),
      }).eq('id', tecnicoId);

      await loadPendingTechnicians();
      await loadStats();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleUserActive(String userId, bool activo) async {
    try {
      await _client
          .from(AppConstants.tableUsuarios)
          .update({'activo': activo})
          .eq('id', userId);
      await loadUsers();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final adminNotifierProvider =
    StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier(ref.read(supabaseClientProvider));
});
