import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/helpers.dart';
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
      final users = await _client.from(AppConstants.tableUsuarios).select(
            'id, rol, activo, creado_en, account_disabled_at',
          );

      final emergencies =
          await _client.from(AppConstants.tableEmergencias).select(
                'id, usuario_id, fecha, estado',
              );

      final tecnicos = await _client.from(AppConstants.tableTecnicos).select(
            'id, usuario_id, estado_verificacion, disponible, calificacion_promedio, total_servicios',
          );

      final ratings = await _client.from(AppConstants.tableCalificaciones).select(
            'calificado_id, puntuacion, fecha',
          );

      final userList = List<Map<String, dynamic>>.from(
        (users as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      final emList = List<Map<String, dynamic>>.from(
        (emergencies as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      final techList = List<Map<String, dynamic>>.from(
        (tecnicos as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      final ratingList = List<Map<String, dynamic>>.from(
        (ratings as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );

      final totalUsers = userList.length;
      final activeUsers =
          userList.where((u) => (u['activo'] as bool?) ?? true).length;
      final disabledUsers = totalUsers - activeUsers;
      final driverCount = userList
          .where((u) => u['rol'] == AppConstants.roleDriver)
          .length;
      final technicianUsers = userList
          .where((u) => u['rol'] == AppConstants.roleTechnician)
          .length;
      final adminCount = userList
          .where((u) => u['rol'] == AppConstants.roleAdmin)
          .length;

      final pendingValidations = techList
          .where((t) =>
              t['estado_verificacion'] == AppConstants.verificationPending)
          .length;
      final approvedTechnicians = techList
          .where((t) =>
              t['estado_verificacion'] == AppConstants.verificationApproved)
          .length;
      final rejectedTechnicians = techList
          .where((t) =>
              t['estado_verificacion'] == AppConstants.verificationRejected)
          .length;
      final availableTechnicians = techList
          .where((t) =>
              t['estado_verificacion'] == AppConstants.verificationApproved &&
              (t['disponible'] as bool? ?? false))
          .length;

      final activeEmergencies = emList
          .where((e) =>
              e['estado'] == AppConstants.statusPending ||
              e['estado'] == AppConstants.statusInProgress)
          .length;
      final completedEmergencies = emList
          .where((e) =>
              e['estado'] == AppConstants.statusCompleted ||
              e['estado'] == AppConstants.statusAttended)
          .length;
      final cancelledEmergencies = emList
          .where((e) => e['estado'] == AppConstants.statusCancelled)
          .length;
      final completionRate = emList.isEmpty
          ? 0
          : ((completedEmergencies / emList.length) * 100).round();

      final avgTechnicianRating = _average(
        techList
            .map((t) => (t['calificacion_promedio'] as num?)?.toDouble() ?? 0)
            .where((value) => value > 0),
      );
      final avgServicesPerTechnician = _average(
        techList.map((t) => (t['total_servicios'] as num?)?.toDouble() ?? 0),
      );
      final lowRatedTechnicians = techList
          .where((t) =>
              ((t['total_servicios'] as num?)?.toInt() ?? 0) >= 3 &&
              ((t['calificacion_promedio'] as num?)?.toDouble() ?? 0) > 0 &&
              ((t['calificacion_promedio'] as num?)?.toDouble() ?? 0) < 4.0)
          .length;

      final newUsers7d = userList
          .where((u) => _isWithinDays(u['creado_en'], 7))
          .length;
      final newUsers30d = userList
          .where((u) => _isWithinDays(u['creado_en'], 30))
          .length;
      final disabledLast30d = userList
          .where((u) => _isWithinDays(u['account_disabled_at'], 30))
          .length;

      final growth7d = _buildUserGrowthSeries(userList, 7);
      final roleDistribution = [
        {'label': 'Conductores', 'count': driverCount},
        {'label': 'Tecnicos', 'count': technicianUsers},
        {'label': 'Admins', 'count': adminCount},
      ];
      final alerts = _buildUserAlerts(
        pendingValidations: pendingValidations,
        disabledUsers: disabledUsers,
        lowRatedTechnicians: lowRatedTechnicians,
        activeEmergencies: activeEmergencies,
        completionRate: completionRate,
      );
      final suggestions = _buildDecisionSuggestions(
        pendingValidations: pendingValidations,
        disabledUsers: disabledUsers,
        lowRatedTechnicians: lowRatedTechnicians,
        availableTechnicians: availableTechnicians,
        activeEmergencies: activeEmergencies,
      );

      state = state.copyWith(
        isLoading: false,
        stats: {
          'total_users': totalUsers,
          'active_users': activeUsers,
          'disabled_users': disabledUsers,
          'driver_count': driverCount,
          'technician_count': technicianUsers,
          'admin_count': adminCount,
          'total_technicians': techList.length,
          'approved_technicians': approvedTechnicians,
          'pending_validations': pendingValidations,
          'rejected_technicians': rejectedTechnicians,
          'available_technicians': availableTechnicians,
          'active_emergencies': activeEmergencies,
          'completed_emergencies': completedEmergencies,
          'cancelled_emergencies': cancelledEmergencies,
          'completion_rate': completionRate,
          'avg_technician_rating': avgTechnicianRating,
          'avg_services_per_technician': avgServicesPerTechnician,
          'new_users_7d': newUsers7d,
          'new_users_30d': newUsers30d,
          'disabled_last_30d': disabledLast30d,
          'growth_7d': growth7d,
          'role_distribution': roleDistribution,
          'alerts': alerts,
          'suggestions': suggestions,
          'ratings_count': ratingList.length,
        },
      );
    } catch (e) {
      debugPrint('[AutoResQ] loadStats ERROR: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  bool _isWithinDays(dynamic value, int days) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return false;
    final diff = AppHelpers.appNow().difference(AppHelpers.toAppTime(date));
    return diff.inDays >= 0 && diff.inDays < days;
  }

  double _average(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  List<Map<String, dynamic>> _buildUserGrowthSeries(
    List<Map<String, dynamic>> users,
    int days,
  ) {
    final now = AppHelpers.appNow();
    final counts = <String, int>{};

    for (var offset = days - 1; offset >= 0; offset--) {
      final day = now.subtract(Duration(days: offset));
      final key = '${day.year}-${day.month}-${day.day}';
      counts[key] = 0;
    }

    for (final user in users) {
      final created = DateTime.tryParse(user['creado_en']?.toString() ?? '');
      if (created == null) continue;
      final appDate = AppHelpers.toAppTime(created);
      final key = '${appDate.year}-${appDate.month}-${appDate.day}';
      if (counts.containsKey(key)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return counts.entries.map((entry) {
      final parts = entry.key.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return {
        'label': '${date.day}/${date.month}',
        'count': entry.value,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _buildUserAlerts({
    required int pendingValidations,
    required int disabledUsers,
    required int lowRatedTechnicians,
    required int activeEmergencies,
    required int completionRate,
  }) {
    final alerts = <Map<String, dynamic>>[];

    if (pendingValidations > 0) {
      alerts.add({
        'label': 'Validaciones pendientes',
        'count': pendingValidations,
        'tone': 'warning',
      });
    }
    if (disabledUsers > 0) {
      alerts.add({
        'label': 'Cuentas desactivadas',
        'count': disabledUsers,
        'tone': 'danger',
      });
    }
    if (lowRatedTechnicians > 0) {
      alerts.add({
        'label': 'Tecnicos con baja calificacion',
        'count': lowRatedTechnicians,
        'tone': 'danger',
      });
    }
    if (activeEmergencies > 0 && completionRate < 70) {
      alerts.add({
        'label': 'Presion operativa',
        'count': activeEmergencies,
        'tone': 'info',
      });
    }

    return alerts;
  }

  List<String> _buildDecisionSuggestions({
    required int pendingValidations,
    required int disabledUsers,
    required int lowRatedTechnicians,
    required int availableTechnicians,
    required int activeEmergencies,
  }) {
    final suggestions = <String>[];

    if (pendingValidations > 0) {
      suggestions.add(
        'Revisar tecnicos pendientes para aumentar la capacidad operativa.',
      );
    }
    if (availableTechnicians < 3 && activeEmergencies > 0) {
      suggestions.add(
        'Hay poca cobertura tecnica disponible frente a la demanda activa.',
      );
    }
    if (lowRatedTechnicians > 0) {
      suggestions.add(
        'Conviene auditar a los tecnicos con menor calificacion antes de que afecten la retencion.',
      );
    }
    if (disabledUsers > 0) {
      suggestions.add(
        'Revisar cuentas desactivadas y solicitudes de reactivacion para evitar fuga de usuarios.',
      );
    }

    if (suggestions.isEmpty) {
      suggestions.add(
        'La base de usuarios se ve estable; puedes enfocarte en crecimiento y calidad de servicio.',
      );
    }

    return suggestions;
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
