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
      final users =
          await _client.from(AppConstants.tableUsuarios).select('rol, activo');

      final emergencies =
          await _client.from(AppConstants.tableEmergencias).select('estado');

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
          .select(
            '*, '
            'tecnicos!usuario_id(estado_verificacion), '
            'account_reactivation_requests!account_reactivation_requests_user_id_fkey(id, reason, evidence_url, evidence_file_name, status, admin_response, created_at, reviewed_at)',
          )
          .order('creado_en', ascending: false);
      final users = List<Map<String, dynamic>>.from(
        (data as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );

      final completedEmergencies = await _client
          .from(AppConstants.tableEmergencias)
          .select(
            'id, usuario_id, descripcion, clasificacion_ia, ai_emergency_type, fecha, estado',
          )
          .eq('estado', AppConstants.statusCompleted);
      final assignments = await _client
          .from(AppConstants.tableAsignaciones)
          .select(
            'emergencia_id, tecnico_id, estado, fecha_asignacion, '
            'tecnicos(id, usuario_id, usuarios!usuario_id(nombre))',
          )
          .neq('estado', AppConstants.assignRejected)
          .order('fecha_asignacion', ascending: false);
      final technicians = await _client
          .from(AppConstants.tableTecnicos)
          .select('id, usuario_id, especialidad');
      final ratings = await _client
          .from(AppConstants.tableCalificaciones)
          .select(
            'id, emergencia_id, calificador_id, calificado_id, puntuacion, comentario, rater_role, fecha',
          );

      final enrichedUsers = _attachUserServiceMetrics(
        users: users,
        emergencies: List<Map<String, dynamic>>.from(completedEmergencies),
        assignments: List<Map<String, dynamic>>.from(assignments),
        technicians: List<Map<String, dynamic>>.from(technicians),
        ratings: List<Map<String, dynamic>>.from(ratings),
      );

      state = state.copyWith(
        isLoading: false,
        users: enrichedUsers,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<Map<String, dynamic>> _attachUserServiceMetrics({
    required List<Map<String, dynamic>> users,
    required List<Map<String, dynamic>> emergencies,
    required List<Map<String, dynamic>> assignments,
    required List<Map<String, dynamic>> technicians,
    required List<Map<String, dynamic>> ratings,
  }) {
    final usersById = {
      for (final user in users) user['id']?.toString() ?? '': user,
    }..remove('');
    final techniciansById = {
      for (final technician in technicians)
        technician['id']?.toString() ?? '': technician,
    }..remove('');
    final emergenciesById = {
      for (final emergency in emergencies)
        emergency['id']?.toString() ?? '': emergency,
    }..remove('');
    final assignmentByEmergency = <String, Map<String, dynamic>>{};
    for (final assignment in assignments) {
      final emergencyId = assignment['emergencia_id']?.toString();
      if (emergencyId == null || emergencyId.isEmpty) continue;
      final current = assignmentByEmergency[emergencyId];
      if (current == null || _isBetterAssignment(assignment, current)) {
        assignmentByEmergency[emergencyId] = assignment;
      }
    }

    return users.map((user) {
      final userId = user['id']?.toString() ?? '';
      final serviceHistory = <Map<String, dynamic>>[];

      for (final emergency in emergencies) {
        final emergencyId = emergency['id']?.toString() ?? '';
        if (emergencyId.isEmpty) continue;
        final assignment = assignmentByEmergency[emergencyId];
        final assignmentTechnicianId = assignment?['tecnico_id']?.toString();
        final joinedTechnician = _firstMap(assignment?['tecnicos']);
        final technician = assignmentTechnicianId == null
            ? joinedTechnician
            : techniciansById[assignmentTechnicianId] ?? joinedTechnician;
        final rawTechnicianUserId = technician?['usuario_id']?.toString();
        final technicianUserId = rawTechnicianUserId?.isNotEmpty == true
            ? rawTechnicianUserId
            : usersById.containsKey(assignmentTechnicianId)
                ? assignmentTechnicianId
                : null;
        final joinedTechnicianUser = _firstMap(joinedTechnician?['usuarios']);
        final joinedTechnicianName =
            joinedTechnicianUser?['nombre']?.toString().trim();
        final storedTechnicianName = technicianUserId == null
            ? null
            : usersById[technicianUserId]?['nombre']?.toString().trim();
        final technicianName = storedTechnicianName?.isNotEmpty == true
            ? storedTechnicianName!
            : joinedTechnicianName?.isNotEmpty == true
                ? joinedTechnicianName!
                : 'Tecnico no identificado';
        final driverId = emergency['usuario_id']?.toString() ?? '';
        final driverName = usersById[driverId]?['nombre']?.toString() ??
            'Conductor no identificado';

        if (driverId == userId) {
          serviceHistory.add(
            _serviceHistoryItem(
              emergency: emergency,
              roleLabel: 'Conductor',
              counterpartLabel: 'atendido por',
              counterpartName: technicianName,
              rating: _ratingFor(
                ratings,
                emergencyId: emergencyId,
                ratedUserId: userId,
                raterRole: 'technician',
              ),
            ),
          );
        }

        if (technicianUserId == userId) {
          serviceHistory.add(
            _serviceHistoryItem(
              emergency: emergency,
              roleLabel: 'Tecnico',
              counterpartLabel: 'atendio a',
              counterpartName: driverName,
              rating: _ratingFor(
                ratings,
                emergencyId: emergencyId,
                ratedUserId: userId,
                raterRole: 'driver',
              ),
            ),
          );
        }
      }

      final historyEmergencyIds = serviceHistory
          .map((item) => item['emergency_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      for (final rating in ratings) {
        final ratedUserId = rating['calificado_id']?.toString() ?? '';
        if (ratedUserId != userId) continue;

        final emergencyId = rating['emergencia_id']?.toString() ?? '';
        if (emergencyId.isEmpty || historyEmergencyIds.contains(emergencyId)) {
          continue;
        }

        final emergency = emergenciesById[emergencyId] ??
            <String, dynamic>{
              'id': emergencyId,
              'fecha': rating['fecha'],
              'descripcion': '',
            };
        final raterId = rating['calificador_id']?.toString() ?? '';
        final raterName =
            usersById[raterId]?['nombre']?.toString().trim();
        serviceHistory.add(
          _serviceHistoryItem(
            emergency: emergency,
            roleLabel: _adminRoleLabel(user['rol']?.toString()),
            counterpartLabel: 'calificado por',
            counterpartName: raterName?.isNotEmpty == true
                ? raterName!
                : 'Usuario no identificado',
            rating: rating,
          ),
        );
        historyEmergencyIds.add(emergencyId);
      }

      serviceHistory.sort(
        (a, b) => (b['date']?.toString() ?? '')
            .compareTo(a['date']?.toString() ?? ''),
      );
      final ratingsForUser = ratings
          .where((rating) => rating['calificado_id']?.toString() == userId)
          .map((rating) => (rating['puntuacion'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      final calculatedAverage = ratingsForUser.isEmpty
          ? 0.0
          : ratingsForUser.reduce((a, b) => a + b) / ratingsForUser.length;
      final storedAverage =
          (user['calificacion_promedio'] as num?)?.toDouble() ?? 0.0;
      final storedTotal = (user['total_servicios'] as num?)?.toInt() ?? 0;

      return {
        ...user,
        'admin_rating_average':
            storedAverage > 0 ? storedAverage : calculatedAverage,
        'admin_services_count':
            storedTotal > serviceHistory.length ? storedTotal : serviceHistory.length,
        'admin_service_history': serviceHistory,
      };
    }).toList();
  }

  Map<String, dynamic>? _firstMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) return _firstMap(value.first);
    return null;
  }

  int _assignmentPriority(String? status) {
    switch (status) {
      case AppConstants.assignFinished:
        return 4;
      case AppConstants.assignAttending:
        return 3;
      case AppConstants.assignEnRoute:
        return 2;
      case AppConstants.assignAccepted:
        return 1;
      default:
        return 0;
    }
  }

  bool _isBetterAssignment(
    Map<String, dynamic> candidate,
    Map<String, dynamic> current,
  ) {
    final candidatePriority =
        _assignmentPriority(candidate['estado']?.toString());
    final currentPriority = _assignmentPriority(current['estado']?.toString());
    if (candidatePriority != currentPriority) {
      return candidatePriority > currentPriority;
    }

    final candidateDate =
        DateTime.tryParse(candidate['fecha_asignacion']?.toString() ?? '');
    final currentDate =
        DateTime.tryParse(current['fecha_asignacion']?.toString() ?? '');
    if (candidateDate == null) return false;
    if (currentDate == null) return true;
    return candidateDate.isAfter(currentDate);
  }

  String _adminRoleLabel(String? role) {
    switch (role) {
      case AppConstants.roleDriver:
        return 'Conductor';
      case AppConstants.roleTechnician:
        return 'Tecnico';
      case AppConstants.roleAdmin:
        return 'Admin';
      default:
        return 'Usuario';
    }
  }

  Map<String, dynamic> _serviceHistoryItem({
    required Map<String, dynamic> emergency,
    required String roleLabel,
    required String counterpartLabel,
    required String counterpartName,
    Map<String, dynamic>? rating,
  }) {
    final serviceName = emergency['ai_emergency_type']?.toString() ??
        emergency['clasificacion_ia']?.toString() ??
        'Emergencia';
    return {
      'emergency_id': emergency['id'],
      'role_label': roleLabel,
      'counterpart_label': counterpartLabel,
      'counterpart_name': counterpartName,
      'service_name': serviceName,
      'description': emergency['descripcion']?.toString() ?? '',
      'date': emergency['fecha']?.toString() ?? rating?['fecha']?.toString(),
      'rating': (rating?['puntuacion'] as num?)?.toInt(),
      'comment': rating?['comentario']?.toString(),
      'rating_date': rating?['fecha']?.toString(),
    };
  }

  Map<String, dynamic>? _ratingFor(
    List<Map<String, dynamic>> ratings, {
    required String emergencyId,
    required String ratedUserId,
    required String raterRole,
  }) {
    for (final rating in ratings) {
      if (rating['emergencia_id']?.toString() == emergencyId &&
          rating['calificado_id']?.toString() == ratedUserId &&
          rating['rater_role']?.toString() == raterRole) {
        return rating;
      }
    }
    return null;
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
      final technicianRow = await _client
          .from(AppConstants.tableTecnicos)
          .select('usuario_id')
          .eq('id', tecnicoId)
          .single();
      final userId = technicianRow['usuario_id'] as String?;

      await _client.from(AppConstants.tableTecnicos).update({
        'estado_verificacion': AppConstants.verificationApproved,
        'verificado_por': uid,
        'fecha_verificacion': DateTime.now().toIso8601String(),
      }).eq('id', tecnicoId);

      if (userId != null) {
        await _client
            .from(AppConstants.tableUsuarios)
            .update({'rol': AppConstants.roleTechnician}).eq('id', userId);
      }

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
      final technicianRow = await _client
          .from(AppConstants.tableTecnicos)
          .select('usuario_id')
          .eq('id', tecnicoId)
          .single();
      final userId = technicianRow['usuario_id'] as String?;

      await _client.from(AppConstants.tableTecnicos).update({
        'estado_verificacion': AppConstants.verificationRejected,
        'verificado_por': uid,
        'fecha_verificacion': DateTime.now().toIso8601String(),
        if (rejectionReason != null && rejectionReason.isNotEmpty)
          'motivo_rechazo': rejectionReason,
      }).eq('id', tecnicoId);

      if (userId != null) {
        await _client
            .from(AppConstants.tableUsuarios)
            .update({'rol': AppConstants.roleDriver}).eq('id', userId);
      }

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

  Future<bool> toggleUserActive(
    String userId,
    bool activo, {
    String? reason,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;
      if (adminId != null && adminId == userId && !activo) {
        state = state.copyWith(error: 'No puedes desactivar tu propia cuenta.');
        return false;
      }

      final trimmedReason = reason?.trim();
      if (!activo && (trimmedReason == null || trimmedReason.length < 8)) {
        state = state.copyWith(
          error: 'Ingresa un motivo de desactivacion.',
        );
        return false;
      }

      final userRow = await _client
          .from(AppConstants.tableUsuarios)
          .select('id, nombre, email')
          .eq('id', userId)
          .single();

      await _client.from(AppConstants.tableUsuarios).update({
        'activo': activo,
        if (!activo) ...{
          'account_disabled_reason': trimmedReason,
          'account_disabled_at': DateTime.now().toIso8601String(),
          'account_disabled_by': adminId,
        } else ...{
          'account_disabled_reason': null,
          'account_disabled_at': null,
          'account_disabled_by': null,
        },
      }).eq('id', userId);

      if (activo) {
        await _client
            .from(AppConstants.tableAccountReactivationRequests)
            .update({
              'status': 'approved',
              'admin_response': 'Cuenta reactivada por el administrador.',
              'reviewed_by': adminId,
              'reviewed_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('status', 'pending');
      } else {
        try {
          await _client.functions.invoke(
            'send-rejection-email',
            body: {
              'kind': 'account_disabled',
              'email': userRow['email'],
              'nombre': userRow['nombre'],
              'motivo': trimmedReason,
            },
          );
        } catch (e) {
          debugPrint('[AutoResQ] toggleUserActive: correo no enviado - $e');
        }
      }

      await loadUsers();
      await loadStats();
      return true;
    } catch (e) {
      debugPrint('[AutoResQ] toggleUserActive ERROR: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> reviewReactivationRequest({
    required String userId,
    required String requestId,
    required bool approved,
    String? response,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;
      final responseText = response?.trim();
      final now = DateTime.now().toIso8601String();

      if (requestId.isEmpty || userId.isEmpty) {
        state = state.copyWith(error: 'Solicitud de reactivacion invalida.');
        return false;
      }

      if (!approved && (responseText == null || responseText.length < 8)) {
        state = state.copyWith(
          error: 'Ingresa una respuesta para rechazar la solicitud.',
        );
        return false;
      }

      if (approved) {
        await _client.from(AppConstants.tableUsuarios).update({
          'activo': true,
          'account_disabled_reason': null,
          'account_disabled_at': null,
          'account_disabled_by': null,
        }).eq('id', userId);
      }

      await _client
          .from(AppConstants.tableAccountReactivationRequests)
          .update({
            'status': approved ? 'approved' : 'rejected',
            'admin_response': responseText?.isNotEmpty == true
                ? responseText
                : 'Cuenta reactivada por el administrador.',
            'reviewed_by': adminId,
            'reviewed_at': now,
          })
          .eq('id', requestId)
          .eq('user_id', userId);

      await loadUsers();
      await loadStats();
      return true;
    } catch (e) {
      debugPrint('[AutoResQ] reviewReactivationRequest ERROR: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final adminNotifierProvider =
    StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier(ref.read(supabaseClientProvider));
});
