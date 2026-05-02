import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/auth_provider.dart';

class AdminState {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> pendingTechnicians;
  final List<Map<String, dynamic>> emergencies;
  final bool isLoading;
  final String? error;

  const AdminState({
    this.stats = const {},
    this.users = const [],
    this.pendingTechnicians = const [],
    this.emergencies = const [],
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? users,
    List<Map<String, dynamic>>? pendingTechnicians,
    List<Map<String, dynamic>>? emergencies,
    bool? isLoading,
    String? error,
  }) {
    return AdminState(
      stats: stats ?? this.stats,
      users: users ?? this.users,
      pendingTechnicians: pendingTechnicians ?? this.pendingTechnicians,
      emergencies: emergencies ?? this.emergencies,
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
      debugPrint('[AutoResQ] loadStats ERROR: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _client
          .from(AppConstants.tableUsuarios)
          .select('*, tecnicos!usuario_id(estado_verificacion)')
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
          .select(
            'id, usuario_id, especialidad, estado_verificacion, disponible, url_credencial, '
            'usuarios!usuario_id(nombre, email, telefono)',
          )
          .eq('estado_verificacion', AppConstants.verificationPending);

      state = state.copyWith(
        isLoading: false,
        pendingTechnicians: List<Map<String, dynamic>>.from(data),
      );
    } catch (e) {
      debugPrint('[AutoResQ] loadPendingTechnicians ERROR: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAllEmergencies() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _client
          .from(AppConstants.tableEmergencias)
          .select(
            '*,'
            'usuarios!usuario_id(nombre, email, telefono),'
            'ubicaciones(latitud, longitud, direccion),'
            'asignaciones(id, estado, tecnicos(especialidad, usuarios!usuario_id(nombre)))',
          )
          .order('fecha', ascending: false);

      state = state.copyWith(
        isLoading: false,
        emergencies: List<Map<String, dynamic>>.from(data),
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

  Future<bool> rejectTechnician(String tecnicoId, {String? motivo}) async {
    try {
      final uid = _client.auth.currentUser?.id;
      final rejectionReason = motivo?.trim();
      await _client.from(AppConstants.tableTecnicos).update({
        'estado_verificacion': AppConstants.verificationRejected,
        'verificado_por': uid,
        'fecha_verificacion': DateTime.now().toIso8601String(),
        if (rejectionReason != null && rejectionReason.isNotEmpty)
          'motivo_rechazo': rejectionReason,
      }).eq('id', tecnicoId);

      // Enviar correo de rechazo. Si falla no revierte el rechazo en DB.
      try {
        final row = await _client
            .from(AppConstants.tableTecnicos)
            .select('usuarios!usuario_id(email, nombre)')
            .eq('id', tecnicoId)
            .single();
        final usuario = row['usuarios'] as Map<String, dynamic>?;
        final email = usuario?['email'] as String?;
        final nombre = usuario?['nombre'] as String?;
        if (email != null && nombre != null) {
          await _client.functions.invoke(
            'send-rejection-email',
            body: {
              'email': email,
              'nombre': nombre,
              'motivo': rejectionReason,
            },
          );
          debugPrint('[AutoResQ] rejectTechnician: correo enviado a $email');
        }
      } catch (e) {
        debugPrint('[AutoResQ] rejectTechnician: correo no enviado — $e');
      }

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
