import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../data/services/admin_report_pdf_service.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/admin_bottom_nav.dart';
import '../providers/admin_provider.dart';

enum _ReportType {
  users,
  technicians,
  requests,
  ratings,
  operations,
  aiDiagnostics,
}

enum _ReportVisualState {
  ready,
  loading,
  empty,
  error,
  denied,
}

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  _ReportType _selectedType = _ReportType.users;
  _ReportVisualState _visualState = _ReportVisualState.loading;
  DateTimeRange? _dateRange;
  String? _selectedRole;
  String? _selectedStatus;
  String? _selectedSpecialty;
  String? _selectedProblemType;
  String? _selectedZone;
  RangeValues _ratingRange = const RangeValues(0, 5);
  String? _errorMessage;
  List<Map<String, dynamic>> _previewRows = const [];
  Map<String, dynamic> _preparedReportData = const {};
  List<Map<String, dynamic>> _reportEmergencies = const [];
  List<Map<String, dynamic>> _ratings = const [];
  Map<String, Map<String, dynamic>> _technicianDetailsByUserId = const {};
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReportData());
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.adminDashboard);
        break;
      case 1:
        context.go(AppRoutes.userManagement);
        break;
      case 2:
        context.go(AppRoutes.technicianValidation);
        break;
      case 3:
        context.go(AppRoutes.emergencyMonitor);
        break;
      case 4:
        break;
    }
  }

  Future<void> _loadReportData({bool preparingPdf = false}) async {
    final user = ref.read(authNotifierProvider).value;
    if (user?.isAdmin != true) {
      setState(() {
        _visualState = _ReportVisualState.denied;
        _previewRows = const [];
        _preparedReportData = const {};
      });
      return;
    }

    setState(() {
      _visualState = _ReportVisualState.loading;
      _errorMessage = null;
    });

    try {
      final adminNotifier = ref.read(adminNotifierProvider.notifier);
      switch (_selectedType) {
        case _ReportType.users:
          await adminNotifier.loadUsers();
          break;
        case _ReportType.technicians:
          await adminNotifier.loadUsers();
          await _loadTechnicianDetails();
          break;
        case _ReportType.requests:
          await _loadDetailedEmergencies();
          break;
        case _ReportType.ratings:
          await adminNotifier.loadUsers();
          await _loadDetailedEmergencies();
          await _loadTechnicianDetails();
          await _loadRatings();
          break;
        case _ReportType.operations:
          await Future.wait([
            adminNotifier.loadStats(),
            adminNotifier.loadUsers(),
          ]);
          await _loadDetailedEmergencies();
          await _loadRatings();
          await _loadTechnicianDetails();
          break;
        case _ReportType.aiDiagnostics:
          await _loadDetailedEmergencies();
          break;
      }

      final rows = _buildPreviewRows(ref.read(adminNotifierProvider));
      final prepared = _buildPreparedReportData(
        state: ref.read(adminNotifierProvider),
        rows: rows,
      );
      if (!mounted) return;

      setState(() {
        _previewRows = rows;
        _preparedReportData = prepared;
        _visualState =
            rows.isEmpty ? _ReportVisualState.empty : _ReportVisualState.ready;
      });

      if (preparingPdf && rows.isNotEmpty && mounted) {
        AppHelpers.showSnackBar(
          context,
          'Datos reales listos para exportarse a PDF.',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _visualState = _ReportVisualState.error;
        _previewRows = const [];
        _preparedReportData = const {};
      });
    }
  }

  Future<void> _loadTechnicianDetails() async {
    final data = await ref
        .read(supabaseClientProvider)
        .from(AppConstants.tableTecnicos)
        .select(
          'usuario_id, especialidad, estado_verificacion, disponible, calificacion_promedio, total_servicios, ubicacion_lat, ubicacion_lng',
        );

    _technicianDetailsByUserId = {
      for (final row in List<Map<String, dynamic>>.from(data))
        row['usuario_id']?.toString() ?? '': row,
    }..remove('');
  }

  Future<void> _loadRatings() async {
    final data = await ref.read(supabaseClientProvider).from(
      AppConstants.tableCalificaciones,
    ).select(
      'id, emergencia_id, calificador_id, calificado_id, puntuacion, comentario, rater_role, fecha',
    );
    _ratings = List<Map<String, dynamic>>.from(data);
  }

  Future<void> _loadDetailedEmergencies() async {
    final data = await ref.read(supabaseClientProvider).from(
      AppConstants.tableEmergencias,
    ).select(
      'id, usuario_id, tipo_problema_id, descripcion, clasificacion_ia, ai_emergency_type, ai_user_message, ai_safety_recommendation, ai_technician_summary, ai_analysis_status, ai_analyzed_at, payment_method, fecha, estado, '
      'usuarios!usuario_id(id, nombre, email), '
      'tipos_problema(nombre), '
      'ubicaciones(latitud, longitud, direccion), '
      'asignaciones(id, tecnico_id, fecha_asignacion, fecha_llegada, estado, tecnicos(id, usuario_id, especialidad, calificacion_promedio, usuarios!usuario_id(id, nombre, email))), '
      'emergency_price_snapshots(estimated_total, protected_total, final_total, pricing_status, created_at), '
      'technician_offers(id, tecnico_id, estado, monto_ofertado), '
      'historial(tipo_evento, descripcion, fecha)',
    ).order('fecha', ascending: false);
    _reportEmergencies = List<Map<String, dynamic>>.from(data);
  }

  List<Map<String, dynamic>> _buildPreviewRows(AdminState state) {
    switch (_selectedType) {
      case _ReportType.users:
        return _filterUsers(state.users);
      case _ReportType.technicians:
        return _filterTechnicians(state.users);
      case _ReportType.requests:
        return _filterEmergencies(_reportEmergencies);
      case _ReportType.ratings:
        return _filterRatings(state);
      case _ReportType.operations:
        return _filterOperations(state);
      case _ReportType.aiDiagnostics:
        return _filterAiDiagnostics(_reportEmergencies);
    }
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    return users.where((user) {
      final createdAt = DateTime.tryParse(user['creado_en']?.toString() ?? '');
      final role = user['rol']?.toString();
      final accountState = _userAccountState(user);
      if (!_matchesDate(createdAt)) return false;
      if (_selectedRole != null && _selectedRole != role) return false;
      if (_selectedStatus != null && _selectedStatus != accountState) {
        return false;
      }
      return true;
    }).map((user) {
      return {
        ...user,
        'account_state': _userAccountState(user),
        'last_access': user['ultimo_acceso'] ??
            user['last_sign_in_at'] ??
            user['last_access_at'],
      };
    }).toList();
  }

  List<Map<String, dynamic>> _filterTechnicians(List<Map<String, dynamic>> users) {
    return users.where((user) {
      final role = user['rol']?.toString();
      if (role != AppConstants.roleTechnician) return false;
      final createdAt = DateTime.tryParse(user['creado_en']?.toString() ?? '');
      final details = _technicianDetailsByUserId[user['id']?.toString() ?? ''];
      final specialty = details?['especialidad']?.toString();
      final verification = details?['estado_verificacion']?.toString();
      final available = (details?['disponible'] as bool?) ?? false;
      final rating =
          (details?['calificacion_promedio'] as num?)?.toDouble() ?? 0.0;
      if (!_matchesDate(createdAt)) return false;
      if (_selectedSpecialty != null && _selectedSpecialty != specialty) {
        return false;
      }
      if (!_matchesRating(rating)) return false;
      if (_selectedStatus != null) {
        if (_selectedStatus == 'disponible' && !available) return false;
        if (_selectedStatus == 'no_disponible' && available) return false;
        if (_selectedStatus != 'disponible' &&
            _selectedStatus != 'no_disponible' &&
            _selectedStatus != verification) {
          return false;
        }
      }
      return true;
    }).map((user) {
      final details = _technicianDetailsByUserId[user['id']?.toString() ?? ''];
      final lat = (details?['ubicacion_lat'] as num?)?.toDouble();
      final lng = (details?['ubicacion_lng'] as num?)?.toDouble();
      return {
        ...user,
        'especialidad': details?['especialidad'],
        'estado_verificacion': details?['estado_verificacion'],
        'disponible': details?['disponible'],
        'calificacion_promedio': details?['calificacion_promedio'],
        'total_servicios': details?['total_servicios'],
        'ubicacion_aproximada': _formatApproxLocation(lat, lng),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _filterEmergencies(
    List<Map<String, dynamic>> emergencies,
  ) {
    return emergencies.where((item) {
      final date = DateTime.tryParse(item['fecha']?.toString() ?? '');
      final status = item['estado']?.toString();
      final specialty = _extractEmergencySpecialty(item);
      final problem = _extractProblemType(item);
      final zone = _extractZone(item);
      final rating = _extractEmergencyTechnicianRating(item);
      if (!_matchesDate(date)) return false;
      if (_selectedStatus != null && _selectedStatus != status) return false;
      if (_selectedSpecialty != null && _selectedSpecialty != specialty) {
        return false;
      }
      if (_selectedType == _ReportType.operations && !_matchesRating(rating)) {
        return false;
      }
      if (_selectedProblemType != null && _selectedProblemType != problem) {
        return false;
      }
      if (_selectedZone != null && _selectedZone != zone) return false;
      return true;
    }).map((item) {
      return {
        ...item,
        'request_code': item['id']?.toString().substring(0, 8).toUpperCase(),
        'driver_name': _firstMap(item['usuarios'])?['nombre']?.toString() ?? 'Conductor',
        'technician_name': _extractAssignedTechnicianName(item) ?? 'Sin asignar',
        'problem_type': _extractProblemType(item) ?? _extractCatalogProblemType(item) ?? 'Sin clasificar',
        'accepted_at': _extractAcceptedAt(item)?.toIso8601String(),
        'closed_at': _extractClosedAt(item)?.toIso8601String(),
        'response_minutes': _responseTimeMinutes(item),
        'zone': _extractZone(item),
        'reference_fee': _referenceFeeFor(item),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _filterRatings(AdminState state) {
    final usersById = {
      for (final user in state.users) user['id']?.toString() ?? '': user,
    }..remove('');
    final emergenciesById = {
      for (final emergency in state.emergencies)
        emergency['id']?.toString() ?? '': emergency,
    }..remove('');

    return _ratings.where((rating) {
      final date = DateTime.tryParse(rating['fecha']?.toString() ?? '');
      final score = (rating['puntuacion'] as num?)?.toDouble() ?? 0.0;
      final emergency =
          emergenciesById[rating['emergencia_id']?.toString() ?? ''];
      final problem = _extractProblemType(emergency);
      final zone = _extractZone(emergency);
      final ratedUser = usersById[rating['calificado_id']?.toString() ?? ''];
      final ratedRole = ratedUser?['rol']?.toString();
      final specialty = _technicianDetailsByUserId[
          ratedUser?['id']?.toString() ?? '']?['especialidad']?.toString();
      if (!_matchesDate(date)) return false;
      if (_selectedRole != null && _selectedRole != ratedRole) return false;
      if (!_matchesRating(score)) return false;
      if (_selectedProblemType != null && _selectedProblemType != problem) {
        return false;
      }
      if (_selectedZone != null && _selectedZone != zone) return false;
      if (_selectedSpecialty != null && _selectedSpecialty != specialty) {
        return false;
      }
      return true;
    }).map((rating) {
      final ratedUser = usersById[rating['calificado_id']?.toString() ?? ''];
      final raterUser = usersById[rating['calificador_id']?.toString() ?? ''];
      final emergency =
          emergenciesById[rating['emergencia_id']?.toString() ?? ''];
      return {
        ...rating,
        'rater_name': raterUser?['nombre'] ?? 'Usuario',
        'rated_name': ratedUser?['nombre'] ?? 'Usuario',
        'rated_role': ratedUser?['rol'] ?? 'sin rol',
        'problem_type': _extractProblemType(emergency),
        'zone': _extractZone(emergency),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _filterOperations(AdminState state) {
    final emergencies = _filterEmergencies(_reportEmergencies);
    if (emergencies.isEmpty && state.stats.isEmpty) return const [];

    final activeCount = emergencies
        .where((item) =>
            item['estado'] == AppConstants.statusPending ||
            item['estado'] == AppConstants.statusInProgress)
        .length;
    final completedCount = emergencies
        .where((item) =>
            item['estado'] == AppConstants.statusCompleted ||
            item['estado'] == AppConstants.statusAttended)
        .length;
    final cancelledCount = emergencies
        .where((item) => item['estado'] == AppConstants.statusCancelled)
        .length;
    final pendingCount = emergencies
        .where((item) => item['estado'] == AppConstants.statusPending)
        .length;
    final responseTimes = emergencies
        .map((item) => item['response_minutes'] as double?)
        .whereType<double>()
        .toList();
    final avgResponse = responseTimes.isEmpty
        ? null
        : responseTimes.reduce((a, b) => a + b) / responseTimes.length;
    final specialtyDemand = _countBy(
      emergencies,
      (row) => _resolveSuggestedSpecialty(row),
    );
    final technicianDemand = _countBy(
      emergencies,
      (row) => row['technician_name']?.toString(),
    );
    final zoneDemand = _countBy(
      emergencies,
      (row) => row['zone']?.toString(),
    );
    final trendDemand = _countBy(
      emergencies,
      (row) => _formatDateValue(row['fecha']),
    );

    return [
      {
        'title': 'Capacidad operativa',
        'value': '${state.stats['available_technicians'] ?? 0} técnicos',
        'subtitle':
            '${state.stats['pending_validations'] ?? 0} pendientes de validación',
      },
      {
        'title': 'Solicitudes activas',
        'value': '$activeCount activas',
        'subtitle':
            '$completedCount finalizadas · $cancelledCount canceladas · $pendingCount pendientes',
      },
      {
        'title': 'Calidad de red',
        'value':
            '${(state.stats['avg_technician_rating'] as double? ?? 0).toStringAsFixed(1)} / 5',
        'subtitle':
            '${state.stats['completion_rate'] ?? 0}% de cierre operativo${avgResponse == null ? '' : ' · ${avgResponse.toStringAsFixed(0)} min promedio'}',
      },
      {
        'title': 'Especialidad más solicitada',
        'value': _topEntryLabel(specialtyDemand),
        'subtitle': 'Zona principal: ${_topEntryLabel(zoneDemand)}',
      },
      {
        'title': 'Técnico con más servicios',
        'value': _topEntryLabel(technicianDemand),
        'subtitle': 'Tendencia: ${_topEntryLabel(trendDemand)}',
      },
    ];
  }

  List<Map<String, dynamic>> _filterAiDiagnostics(
    List<Map<String, dynamic>> emergencies,
  ) {
    return emergencies.where((item) {
      final date = DateTime.tryParse(item['fecha']?.toString() ?? '');
      final status = item['estado']?.toString();
      final problem = _extractProblemType(item);
      final zone = _extractZone(item);
      if (!_matchesDate(date)) return false;
      if ((item['clasificacion_ia']?.toString().trim().isEmpty ?? true) &&
          (item['ai_emergency_type']?.toString().trim().isEmpty ?? true)) {
        return false;
      }
      if (_selectedStatus != null && _selectedStatus != status) return false;
      if (_selectedProblemType != null && _selectedProblemType != problem) {
        return false;
      }
      if (_selectedZone != null && _selectedZone != zone) return false;
      return true;
    }).map((item) {
      return {
        ...item,
        'request_code': item['id']?.toString().substring(0, 8).toUpperCase(),
        'problem_type': _extractProblemType(item) ?? _extractCatalogProblemType(item) ?? 'Sin clasificar',
        'suggested_specialty': _resolveSuggestedSpecialty(item),
        'reference_fee': _referenceFeeFor(item),
        'generated_at':
            item['ai_analyzed_at']?.toString() ?? item['fecha']?.toString(),
        'ai_diagnosis':
            item['ai_technician_summary']?.toString() ??
            item['clasificacion_ia']?.toString() ??
            item['ai_user_message']?.toString() ??
            'Sin diagnóstico disponible',
        'zone': _extractZone(item),
      };
    }).toList();
  }

  bool _matchesDate(DateTime? date) {
    if (_dateRange == null || date == null) return true;
    final local = AppHelpers.toAppTime(date);
    final start = DateTime(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
    );
    final end = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
      23,
      59,
      59,
    );
    return !local.isBefore(start) && !local.isAfter(end);
  }

  bool _matchesRating(double rating) {
    return rating >= _ratingRange.start && rating <= _ratingRange.end;
  }

  String? _extractEmergencySpecialty(Map<String, dynamic>? item) {
    final assignments = item?['asignaciones'];
    final firstAssignment = _firstMap(assignments);
    final tech = _firstMap(firstAssignment?['tecnicos']);
    return tech?['especialidad']?.toString();
  }

  double _extractEmergencyTechnicianRating(Map<String, dynamic>? item) {
    final assignments = item?['asignaciones'];
    final firstAssignment = _firstMap(assignments);
    final tech = _firstMap(firstAssignment?['tecnicos']);
    return (tech?['calificacion_promedio'] as num?)?.toDouble() ?? 0.0;
  }

  String? _extractProblemType(Map<String, dynamic>? item) {
    return item?['ai_emergency_type']?.toString() ??
        item?['clasificacion_ia']?.toString() ??
        _extractCatalogProblemType(item);
  }

  String? _extractCatalogProblemType(Map<String, dynamic>? item) {
    final type = _firstMap(item?['tipos_problema']);
    return type?['nombre']?.toString();
  }

  String? _extractZone(Map<String, dynamic>? item) {
    final location = _firstMap(item?['ubicaciones']);
    return location?['direccion']?.toString();
  }

  Map<String, dynamic>? _firstMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) return _firstMap(value.first);
    return null;
  }

  Set<String> _availableRoles(AdminState state) {
    switch (_selectedType) {
      case _ReportType.users:
        return state.users
            .map((user) => user['rol']?.toString() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet();
      case _ReportType.ratings:
        return state.users
            .map((item) => item['rol']?.toString() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet();
      default:
        return const <String>{};
    }
  }

  Set<String> _availableStatuses(AdminState state) {
    switch (_selectedType) {
      case _ReportType.users:
        return const {'activo', 'inactivo', 'bloqueado'};
      case _ReportType.technicians:
        return const {
          AppConstants.verificationApproved,
          AppConstants.verificationPending,
          AppConstants.verificationRejected,
          'disponible',
          'no_disponible',
        };
      case _ReportType.requests:
      case _ReportType.operations:
      case _ReportType.aiDiagnostics:
        return _reportEmergencies
            .map((item) => item['estado']?.toString() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet();
      default:
        return const <String>{};
    }
  }

  Set<String> _availableSpecialties(AdminState state) {
    final specialties = <String>{};
    if (_selectedType == _ReportType.technicians) {
      for (final item in _technicianDetailsByUserId.values) {
        final specialty = item['especialidad']?.toString();
        if (specialty != null && specialty.isNotEmpty) specialties.add(specialty);
      }
      return specialties;
    }
    for (final emergency in _reportEmergencies) {
      final specialty = _extractEmergencySpecialty(emergency);
      if (specialty != null && specialty.isNotEmpty) specialties.add(specialty);
    }
    return specialties;
  }

  Set<String> _availableProblemTypes(AdminState state) {
    final values = <String>{};
    if (_selectedType == _ReportType.ratings) {
      for (final emergency in _reportEmergencies) {
        final type = _extractProblemType(emergency);
        if (type != null && type.isNotEmpty) values.add(type);
      }
      return values;
    }
    for (final emergency in _reportEmergencies) {
      final type = _extractProblemType(emergency);
      if (type != null && type.isNotEmpty) values.add(type);
    }
    return values;
  }

  Set<String> _availableZones(AdminState state) {
    final zones = <String>{};
    for (final emergency in _reportEmergencies) {
      final zone = _extractZone(emergency);
      if (zone != null && zone.isNotEmpty) zones.add(zone);
    }
    return zones;
  }

  bool get _showsRoleFilter =>
      _selectedType == _ReportType.users || _selectedType == _ReportType.ratings;

  bool get _showsStatusFilter =>
      _selectedType == _ReportType.users ||
      _selectedType == _ReportType.technicians ||
      _selectedType == _ReportType.requests ||
      _selectedType == _ReportType.operations ||
      _selectedType == _ReportType.aiDiagnostics;

  bool get _showsSpecialtyFilter =>
      _selectedType == _ReportType.technicians ||
      _selectedType == _ReportType.requests ||
      _selectedType == _ReportType.operations;

  bool get _showsRatingFilter =>
      _selectedType == _ReportType.technicians ||
      _selectedType == _ReportType.ratings ||
      _selectedType == _ReportType.operations;

  bool get _showsProblemTypeFilter =>
      _selectedType == _ReportType.requests ||
      _selectedType == _ReportType.operations ||
      _selectedType == _ReportType.aiDiagnostics ||
      _selectedType == _ReportType.ratings;

  bool get _showsZoneFilter =>
      _selectedType == _ReportType.requests ||
      _selectedType == _ReportType.operations ||
      _selectedType == _ReportType.aiDiagnostics ||
      _selectedType == _ReportType.ratings;

  void _clearFilters() {
    setState(() {
      _dateRange = null;
      _selectedRole = null;
      _selectedStatus = null;
      _selectedSpecialty = null;
      _selectedProblemType = null;
      _selectedZone = null;
      _ratingRange = const RangeValues(0, 5);
    });
    _loadReportData();
  }

  Map<String, dynamic> _buildPreparedReportData({
    required AdminState state,
    required List<Map<String, dynamic>> rows,
  }) {
    switch (_selectedType) {
      case _ReportType.users:
        return _buildUsersReportPayload(rows);
      case _ReportType.technicians:
        return _buildTechniciansReportPayload(state, rows);
      case _ReportType.requests:
        return _buildRequestsReportPayload(rows);
      case _ReportType.ratings:
        return _buildRatingsReportPayload(state, rows);
      case _ReportType.operations:
        return _buildOperationsReportPayload(state, rows);
      case _ReportType.aiDiagnostics:
        return _buildAiDiagnosticsReportPayload(rows);
    }
  }

  Map<String, dynamic> _buildUsersReportPayload(List<Map<String, dynamic>> rows) {
    final byRole = <String, int>{};
    var active = 0;
    var inactive = 0;
    var blocked = 0;
    for (final row in rows) {
      final role = row['rol']?.toString() ?? 'sin rol';
      final state = row['account_state']?.toString() ?? 'activo';
      byRole[role] = (byRole[role] ?? 0) + 1;
      if (state == 'activo') active++;
      if (state == 'inactivo') inactive++;
      if (state == 'bloqueado') blocked++;
    }
    return {
      'report_type': 'Usuarios',
      'generated_at': DateTime.now().toIso8601String(),
      'filters': _activeFilters(),
      'summary': {
        'total_users': rows.length,
        'users_by_role': byRole,
        'active_users': active,
        'inactive_users': inactive,
        'blocked_users': blocked,
      },
      'rows': rows.map((row) {
        return {
          'nombre': row['nombre'],
          'correo': row['email'],
          'rol': row['rol'],
          'estado_cuenta': row['account_state'],
          'fecha_registro': row['creado_en'],
          'ultimo_acceso': row['last_access'],
        };
      }).toList(),
      'ready_for_pdf': true,
    };
  }

  Map<String, dynamic> _buildTechniciansReportPayload(
    AdminState _,
    List<Map<String, dynamic>> rows,
  ) {
    final pending = rows
        .where(
          (row) =>
              row['estado_verificacion'] == AppConstants.verificationPending,
        )
        .length;
    final bestRated = [...rows]
      ..sort((a, b) => ((b['calificacion_promedio'] as num?)?.toDouble() ?? 0)
          .compareTo((a['calificacion_promedio'] as num?)?.toDouble() ?? 0));
    return {
      'report_type': 'Técnicos',
      'generated_at': DateTime.now().toIso8601String(),
      'filters': _activeFilters(),
      'summary': {
        'total_technicians': rows.length,
        'pending_approval': pending,
        'best_rated_technicians': bestRated.take(3).map((row) {
          return {
            'nombre': row['nombre'],
            'correo': row['email'],
            'calificacion_promedio': row['calificacion_promedio'] ?? 0,
            'especialidad': row['especialidad'],
          };
        }).toList(),
      },
      'rows': rows.map((row) {
        return {
          'nombre': row['nombre'],
          'correo': row['email'],
          'especialidad': row['especialidad'],
          'estado_aprobacion': row['estado_verificacion'],
          'disponibilidad': row['disponible'] == true ? 'disponible' : 'no_disponible',
          'servicios_atendidos': row['total_servicios'] ?? 0,
          'calificacion_promedio': row['calificacion_promedio'] ?? 0,
          'ubicacion_aproximada': row['ubicacion_aproximada'],
        };
      }).toList(),
      'ready_for_pdf': true,
    };
  }

  Map<String, dynamic> _buildRequestsReportPayload(List<Map<String, dynamic>> rows) {
    final byStatus = <String, int>{};
    for (final row in rows) {
      final status = row['estado']?.toString() ?? 'sin estado';
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }
    return {
      'report_type': 'Solicitudes',
      'generated_at': DateTime.now().toIso8601String(),
      'filters': _activeFilters(),
      'summary': {
        'total_requests': rows.length,
        'requests_by_status': byStatus,
      },
      'rows': rows.map((row) {
        return {
          'id_solicitud': row['request_code'],
          'conductor_solicitante': row['driver_name'],
          'tecnico_asignado': row['technician_name'],
          'tipo_problema_vehicular': row['problem_type'],
          'estado_solicitud': row['estado'],
          'fecha_creacion': row['fecha'],
          'fecha_aceptacion': row['accepted_at'],
          'fecha_cierre': row['closed_at'],
          'tiempo_respuesta_minutos': row['response_minutes'],
          'ubicacion_zona': row['zone'],
          'cuota_referencial': row['reference_fee'],
          'metodo_pago': row['payment_method'],
        };
      }).toList(),
      'ready_for_pdf': true,
    };
  }

  Map<String, dynamic> _buildRatingsReportPayload(
    AdminState state,
    List<Map<String, dynamic>> rows,
  ) {
    final average = rows.isEmpty
        ? 0.0
        : rows
                .map((row) => (row['puntuacion'] as num?)?.toDouble() ?? 0)
                .reduce((a, b) => a + b) /
            rows.length;
    final usersById = {
      for (final user in state.users) user['id']?.toString() ?? '': user,
    }..remove('');
    final technicians = _technicianDetailsByUserId.entries
        .map((entry) => {
              'user_id': entry.key,
              ...entry.value,
            })
        .toList();
    final bestRated = [...technicians]
      ..sort((a, b) => ((b['calificacion_promedio'] as num?)?.toDouble() ?? 0)
          .compareTo((a['calificacion_promedio'] as num?)?.toDouble() ?? 0));
    final lowRated = technicians.where((item) {
      final rating = (item['calificacion_promedio'] as num?)?.toDouble() ?? 0;
      final total = (item['total_servicios'] as num?)?.toInt() ?? 0;
      return total > 0 && rating > 0 && rating < 4;
    }).toList()
      ..sort((a, b) => ((a['calificacion_promedio'] as num?)?.toDouble() ?? 0)
          .compareTo((b['calificacion_promedio'] as num?)?.toDouble() ?? 0));
    return {
      'report_type': 'Calificaciones',
      'generated_at': DateTime.now().toIso8601String(),
      'filters': _activeFilters(),
      'summary': {
        'average_rating': average,
        'best_rated_technicians': bestRated.take(3).map((item) {
          return {
            'nombre': usersById[item['user_id']]?['nombre'] ?? 'Técnico',
            'calificacion_promedio': item['calificacion_promedio'] ?? 0,
            'especialidad': item['especialidad'],
          };
        }).toList(),
        'low_rated_technicians': lowRated.take(3).map((item) {
          return {
            'nombre': usersById[item['user_id']]?['nombre'] ?? 'Técnico',
            'calificacion_promedio': item['calificacion_promedio'] ?? 0,
            'especialidad': item['especialidad'],
          };
        }).toList(),
      },
      'rows': rows.map((row) {
        return {
          'usuario_que_califica': row['rater_name'],
          'usuario_calificado': row['rated_name'],
          'rol_usuario_calificado': row['rated_role'],
          'puntuacion': row['puntuacion'],
          'comentario': row['comentario'],
          'fecha': row['fecha'],
        };
      }).toList(),
      'ready_for_pdf': true,
    };
  }

  Map<String, dynamic> _buildOperationsReportPayload(
    AdminState state,
    List<Map<String, dynamic>> rows,
  ) {
    final emergencies = _filterEmergencies(_reportEmergencies);
    final totalRequested = emergencies.length;
    final totalCompleted = emergencies
        .where((item) => item['estado'] == AppConstants.statusCompleted)
        .length;
    final totalCancelled = emergencies
        .where((item) => item['estado'] == AppConstants.statusCancelled)
        .length;
    final totalPending = emergencies
        .where((item) => item['estado'] == AppConstants.statusPending)
        .length;
    final responseValues = emergencies
        .map((item) => item['response_minutes'] as double?)
        .whereType<double>()
        .toList();
    final avgResponse = responseValues.isEmpty
        ? null
        : responseValues.reduce((a, b) => a + b) / responseValues.length;
    return {
      'report_type': 'Desempeño operativo',
      'generated_at': DateTime.now().toIso8601String(),
      'filters': _activeFilters(),
      'summary': {
        'total_services_requested': totalRequested,
        'total_services_completed': totalCompleted,
        'total_services_cancelled': totalCancelled,
        'total_services_pending': totalPending,
        'average_response_minutes': avgResponse,
        'most_requested_specialties': _topMapEntries(
          _countBy(emergencies, (row) => _resolveSuggestedSpecialty(row)),
        ),
        'top_technicians_by_services': _topMapEntries(
          _countBy(emergencies, (row) => row['technician_name']?.toString()),
        ),
        'top_zones_by_demand': _topMapEntries(
          _countBy(emergencies, (row) => row['zone']?.toString()),
        ),
        'general_rating_average': state.stats['avg_technician_rating'],
        'trend_by_day': _countBy(emergencies, (row) => _formatDateValue(row['fecha'])),
      },
      'rows': rows,
      'ready_for_pdf': true,
    };
  }

  Map<String, dynamic> _buildAiDiagnosticsReportPayload(List<Map<String, dynamic>> rows) {
    return {
      'report_type': 'Diagnósticos IA',
      'generated_at': DateTime.now().toIso8601String(),
      'filters': _activeFilters(),
      'summary': {
        'total_ai_diagnostics': rows.length,
        'most_frequent_detected_problems': _topMapEntries(
          _countBy(rows, (row) => row['problem_type']?.toString()),
        ),
      },
      'rows': rows.map((row) {
        return {
          'descripcion_conductor': row['descripcion'],
          'diagnostico_generado_ia': row['ai_diagnosis'],
          'categoria_detectada': row['problem_type'],
          'especialidad_sugerida': row['suggested_specialty'],
          'cuota_referencial_sugerida': row['reference_fee'],
          'solicitud_asociada': row['request_code'],
          'fecha_generacion': row['generated_at'],
        };
      }).toList(),
      'ready_for_pdf': true,
    };
  }

  Map<String, dynamic> _activeFilters() {
    return {
      'date_range': _dateRange == null
          ? null
          : {
              'start': _dateRange!.start.toIso8601String(),
              'end': _dateRange!.end.toIso8601String(),
            },
      'role': _selectedRole,
      'status': _selectedStatus,
      'specialty': _selectedSpecialty,
      'rating_min': _showsRatingFilter ? _ratingRange.start : null,
      'rating_max': _showsRatingFilter ? _ratingRange.end : null,
      'problem_type': _selectedProblemType,
      'zone': _selectedZone,
    };
  }

  String _userAccountState(Map<String, dynamic> user) {
    final active = (user['activo'] as bool?) ?? true;
    if (active) return 'activo';
    final disabledAt = user['account_disabled_at']?.toString();
    return disabledAt != null && disabledAt.isNotEmpty ? 'bloqueado' : 'inactivo';
  }

  String? _formatApproxLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  String _formatDateValue(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return raw?.toString() ?? '';
    final appDate = AppHelpers.toAppTime(date);
    return '${appDate.day}/${appDate.month}/${appDate.year}';
  }

  double? _responseTimeMinutes(Map<String, dynamic> item) {
    final createdAt = DateTime.tryParse(item['fecha']?.toString() ?? '');
    final acceptedAt = _extractAcceptedAt(item);
    if (createdAt == null || acceptedAt == null) return null;
    return acceptedAt.difference(createdAt).inMinutes.toDouble();
  }

  DateTime? _extractAcceptedAt(Map<String, dynamic> item) {
    final assignments = item['asignaciones'];
    if (assignments is List) {
      final validAssignments = assignments
          .map((entry) => entry is Map ? Map<String, dynamic>.from(entry) : null)
          .whereType<Map<String, dynamic>>()
          .where((row) => row['estado'] != AppConstants.assignRejected)
          .toList()
        ..sort((a, b) {
          final aDate = DateTime.tryParse(a['fecha_asignacion']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['fecha_asignacion']?.toString() ?? '');
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });
      if (validAssignments.isNotEmpty) {
        return DateTime.tryParse(
          validAssignments.first['fecha_asignacion']?.toString() ?? '',
        );
      }
    }
    return null;
  }

  DateTime? _extractClosedAt(Map<String, dynamic> item) {
    final history = item['historial'];
    if (history is List) {
      final closing = history
          .map((entry) => entry is Map ? Map<String, dynamic>.from(entry) : null)
          .whereType<Map<String, dynamic>>()
          .where((row) {
            final event = row['tipo_evento']?.toString();
            return event == 'finalizacion' || event == 'cancelacion';
          })
          .toList()
        ..sort((a, b) => (a['fecha']?.toString() ?? '').compareTo(b['fecha']?.toString() ?? ''));
      if (closing.isNotEmpty) {
        return DateTime.tryParse(closing.last['fecha']?.toString() ?? '');
      }
    }
    return null;
  }

  String? _extractAssignedTechnicianName(Map<String, dynamic> item) {
    final assignment = _firstMap(item['asignaciones']);
    final tech = _firstMap(assignment?['tecnicos']);
    final techUser = _firstMap(tech?['usuarios']);
    return techUser?['nombre']?.toString();
  }

  String? _resolveSuggestedSpecialty(Map<String, dynamic> item) {
    return _extractEmergencySpecialty(item) ??
        _mapProblemTypeToSpecialty(_extractProblemType(item));
  }

  String? _mapProblemTypeToSpecialty(String? problemType) {
    if (problemType == null || problemType.isEmpty) return null;
    final value = problemType.toLowerCase();
    if (value.contains('bater') || value.contains('eléctr') || value.contains('electr')) {
      return 'Sistema eléctrico y batería';
    }
    if (value.contains('llanta') || value.contains('vulcan')) {
      return 'Llantas y vulcanización';
    }
    if (value.contains('grúa') || value.contains('grua') || value.contains('remolque')) {
      return 'Grúa / remolque';
    }
    if (value.contains('combustible')) return 'Combustible';
    if (value.contains('cerraj')) return 'Cerrajería vehicular';
    return 'Mecánica rápida';
  }

  String? _referenceFeeFor(Map<String, dynamic> item) {
    final snapshot = _firstMap(item['emergency_price_snapshots']);
    final amount =
        (snapshot?['final_total'] as num?)?.toDouble() ??
        (snapshot?['protected_total'] as num?)?.toDouble() ??
        (snapshot?['estimated_total'] as num?)?.toDouble();
    if (amount != null) return '\$${amount.toStringAsFixed(2)}';

    final offers = item['technician_offers'];
    if (offers is List) {
      final values = offers
          .map((entry) => entry is Map ? (entry['monto_ofertado'] as num?)?.toDouble() : null)
          .whereType<double>()
          .toList();
      if (values.isNotEmpty) {
        values.sort();
        return '\$${values.first.toStringAsFixed(2)}';
      }
    }
    return null;
  }

  Map<String, int> _countBy(
    List<Map<String, dynamic>> rows,
    String? Function(Map<String, dynamic>) selector,
  ) {
    final counts = <String, int>{};
    for (final row in rows) {
      final key = selector(row);
      if (key == null || key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> _topMapEntries(Map<String, int> map, {int take = 3}) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(take).map((entry) {
      return {'label': entry.key, 'count': entry.value};
    }).toList();
  }

  String _topEntryLabel(Map<String, int> map) {
    if (map.isEmpty) return 'Sin datos';
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${entries.first.key} (${entries.first.value})';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (picked == null) return;
    setState(() => _dateRange = picked);
    _loadReportData();
  }

  Future<void> _generatePdf() async {
    final user = ref.read(authNotifierProvider).value;
    if (user?.isAdmin != true) {
      setState(() => _visualState = _ReportVisualState.denied);
      return;
    }
    if (_isGeneratingPdf) return;

    setState(() => _isGeneratingPdf = true);
    try {
      await _loadReportData();
      if (_previewRows.isEmpty || _preparedReportData.isEmpty) {
        if (mounted) {
          AppHelpers.showSnackBar(
            context,
            'No existen datos para los filtros seleccionados',
            isError: true,
          );
        }
        return;
      }

      const service = AdminReportPdfService();
      await service.openReportPdf(
        reportData: _preparedReportData,
        appName: AppConstants.appName,
        adminName: user?.name,
      );
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'No se pudo generar el PDF: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;
    final state = ref.watch(adminNotifierProvider);
    final isAdmin = user?.isAdmin == true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.adminDashboard);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.surfaceContainerLowest,
          leading: IconButton(
            onPressed: () => context.go(AppRoutes.adminDashboard),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text(
            'Reportes administrativos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              onPressed: () => _loadReportData(),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            16,
            AppConstants.pagePadding,
            AppConstants.pagePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReportsHeroCard(
                state: _visualState,
                total: _previewRows.length,
                selectedType: _reportTypeLabel(_selectedType),
              ),
              const Gap(20),
              _SectionLabel('Tipo de reporte'),
              const Gap(10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _ReportType.values.map((type) {
                  final selected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(_reportTypeLabel(type)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedType = type;
                        _selectedRole = null;
                        _selectedStatus = null;
                        _selectedSpecialty = null;
                        _selectedProblemType = null;
                        _selectedZone = null;
                      });
                      _loadReportData();
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.28)
                          : AppColors.surfaceContainerHigh,
                    ),
                    backgroundColor: AppColors.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  );
                }).toList(),
              ),
              const Gap(20),
              _FiltersCard(
                dateRangeLabel: _dateRange == null
                    ? 'Seleccionar rango'
                    : '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}',
                onPickDateRange: _pickDateRange,
                onClear: _clearFilters,
                onGenerate: isAdmin && !_isGeneratingPdf ? _generatePdf : null,
                isGeneratingPdf: _isGeneratingPdf,
                roleFilter: _showsRoleFilter
                    ? _FilterDropdown(
                        label: 'Rol',
                        value: _selectedRole,
                        options: _availableRoles(state).toList()..sort(),
                        onChanged: (value) {
                          setState(() => _selectedRole = value);
                          _loadReportData();
                        },
                      )
                    : null,
                statusFilter: _showsStatusFilter
                    ? _FilterDropdown(
                        label: 'Estado',
                        value: _selectedStatus,
                        options: _availableStatuses(state).toList()..sort(),
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                          _loadReportData();
                        },
                      )
                    : null,
                specialtyFilter: _showsSpecialtyFilter
                    ? _FilterDropdown(
                        label: 'Especialidad',
                        value: _selectedSpecialty,
                        options: _availableSpecialties(state).toList()..sort(),
                        onChanged: (value) {
                          setState(() => _selectedSpecialty = value);
                          _loadReportData();
                        },
                      )
                    : null,
                zoneFilter: _showsZoneFilter
                    ? _FilterDropdown(
                        label: 'Zona / ubicación',
                        value: _selectedZone,
                        options: _availableZones(state).toList()..sort(),
                        onChanged: (value) {
                          setState(() => _selectedZone = value);
                          _loadReportData();
                        },
                      )
                    : null,
                problemTypeFilter: _showsProblemTypeFilter
                    ? _FilterDropdown(
                        label: 'Tipo de problema',
                        value: _selectedProblemType,
                        options: _availableProblemTypes(state).toList()..sort(),
                        onChanged: (value) {
                          setState(() => _selectedProblemType = value);
                          _loadReportData();
                        },
                      )
                    : null,
                ratingFilter: _showsRatingFilter
                    ? _RatingFilter(
                        values: _ratingRange,
                        onChanged: (values) {
                          setState(() => _ratingRange = values);
                        },
                        onChangeEnd: (_) => _loadReportData(),
                      )
                    : null,
              ),
              const Gap(20),
              _StateCard(
                state: _visualState,
                errorMessage: _errorMessage ?? state.error,
                reportName: _reportTypeLabel(_selectedType),
                itemCount: _previewRows.length,
              ),
              const Gap(16),
              if (_visualState == _ReportVisualState.ready ||
                  _visualState == _ReportVisualState.empty)
                _PreviewPanel(
                  rows: _previewRows,
                  type: _selectedType,
                  preparedReportData: _preparedReportData,
                ),
            ],
          ),
        ),
        bottomNavigationBar: isAdmin
            ? AdminBottomNav(
                selectedIndex: 4,
                onItemTapped: _onNavTap,
              )
            : null,
      ),
    );
  }

  String _reportTypeLabel(_ReportType type) {
    switch (type) {
      case _ReportType.users:
        return 'Usuarios';
      case _ReportType.technicians:
        return 'Técnicos';
      case _ReportType.requests:
        return 'Solicitudes';
      case _ReportType.ratings:
        return 'Calificaciones';
      case _ReportType.operations:
        return 'Desempeño operativo';
      case _ReportType.aiDiagnostics:
        return 'Diagnósticos IA';
    }
  }
}

class _ReportsHeroCard extends StatelessWidget {
  final _ReportVisualState state;
  final int total;
  final String selectedType;

  const _ReportsHeroCard({
    required this.state,
    required this.total,
    required this.selectedType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Centro de reportes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Configura filtros reales y deja listo el PDF de $selectedType.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(label: 'Estado: ${_stateLabel(state)}'),
              _HeroBadge(label: '$total registros listos'),
              _HeroBadge(label: selectedType),
            ],
          ),
        ],
      ),
    );
  }

  String _stateLabel(_ReportVisualState value) {
    switch (value) {
      case _ReportVisualState.ready:
        return 'Listo';
      case _ReportVisualState.loading:
        return 'Cargando';
      case _ReportVisualState.empty:
        return 'Sin datos';
      case _ReportVisualState.error:
        return 'Error';
      case _ReportVisualState.denied:
        return 'Acceso denegado';
    }
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;

  const _HeroBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final String dateRangeLabel;
  final VoidCallback onPickDateRange;
  final VoidCallback onClear;
  final VoidCallback? onGenerate;
  final bool isGeneratingPdf;
  final Widget? roleFilter;
  final Widget? statusFilter;
  final Widget? specialtyFilter;
  final Widget? ratingFilter;
  final Widget? problemTypeFilter;
  final Widget? zoneFilter;

  const _FiltersCard({
    required this.dateRangeLabel,
    required this.onPickDateRange,
    required this.onClear,
    required this.onGenerate,
    this.isGeneratingPdf = false,
    this.roleFilter,
    this.statusFilter,
    this.specialtyFilter,
    this.ratingFilter,
    this.problemTypeFilter,
    this.zoneFilter,
  });

  @override
  Widget build(BuildContext context) {
    final fields = [
      roleFilter,
      statusFilter,
      specialtyFilter,
      problemTypeFilter,
      zoneFilter,
      ratingFilter,
    ].whereType<Widget>().toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros dinámicos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(6),
          const Text(
            'Muestra solo los filtros que aplican al reporte seleccionado.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(16),
          _DateFilterTile(
            label: dateRangeLabel,
            onTap: onPickDateRange,
          ),
          if (fields.isNotEmpty) ...[
            const Gap(14),
            ...fields.expand((item) => [item, const Gap(12)]).toList()
              ..removeLast(),
          ],
          const Gap(18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(color: AppColors.surfaceContainerHigh),
                  ),
                  child: const Text('Limpiar filtros'),
                ),
              ),
              const Gap(12),
              Expanded(
                child: FilledButton(
                  onPressed: onGenerate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isGeneratingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Generar PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateFilterTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateFilterTile({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, color: AppColors.primary),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rango de fechas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Gap(8),
        DropdownButtonFormField<String?>(
          initialValue: value,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos'),
            ),
            ...options.map(
              (option) => DropdownMenuItem<String?>(
                value: option,
                child: Text(option),
              ),
            ),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingFilter extends StatelessWidget {
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final ValueChanged<RangeValues> onChangeEnd;

  const _RatingFilter({
    required this.values,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calificación mínima / máxima',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(8),
          Text(
            '${values.start.toStringAsFixed(1)} - ${values.end.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          RangeSlider(
            values: values,
            min: 0,
            max: 5,
            divisions: 10,
            labels: RangeLabels(
              values.start.toStringAsFixed(1),
              values.end.toStringAsFixed(1),
            ),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final _ReportVisualState state;
  final String reportName;
  final int itemCount;
  final String? errorMessage;

  const _StateCard({
    required this.state,
    required this.reportName,
    required this.itemCount,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color tone;
    String title;
    String body;

    switch (state) {
      case _ReportVisualState.ready:
        icon = Icons.task_alt_rounded;
        tone = AppColors.success;
        title = 'Listo';
        body =
            '$itemCount registros de $reportName quedaron listos para la siguiente etapa de exportación.';
        break;
      case _ReportVisualState.loading:
        icon = Icons.hourglass_top_rounded;
        tone = AppColors.primary;
        title = 'Cargando';
        body = 'Preparando datos reales para el reporte seleccionado.';
        break;
      case _ReportVisualState.empty:
        icon = Icons.inbox_outlined;
        tone = AppColors.warning;
        title = 'Sin datos';
        body = 'No existen datos para los filtros seleccionados.';
        break;
      case _ReportVisualState.error:
        icon = Icons.error_outline_rounded;
        tone = AppColors.error;
        title = 'Error';
        body = errorMessage ?? 'No se pudo preparar el reporte.';
        break;
      case _ReportVisualState.denied:
        icon = Icons.lock_outline_rounded;
        tone = AppColors.error;
        title = 'Acceso denegado';
        body = 'Solo los administradores pueden acceder a esta sección.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tone),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Gap(4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final _ReportType type;
  final Map<String, dynamic> preparedReportData;

  const _PreviewPanel({
    required this.rows,
    required this.type,
    required this.preparedReportData,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final visibleRows = rows.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vista previa del reporte',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(6),
          Text(
            'Mostrando ${visibleRows.length} de ${rows.length} resultados.',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          if ((preparedReportData['summary'] as Map?)?.isNotEmpty == true) ...[
            const Gap(14),
            _SummaryWrap(summary: Map<String, dynamic>.from(preparedReportData['summary'] as Map)),
          ],
          const Gap(14),
          ...visibleRows.map((row) => _PreviewTile(type: type, row: row)),
        ],
      ),
    );
  }
}

class _SummaryWrap extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _SummaryWrap({required this.summary});

  @override
  Widget build(BuildContext context) {
    final entries = summary.entries.where((entry) {
      final value = entry.value;
      if (value == null) return false;
      if (value is List) return value.isNotEmpty;
      if (value is Map) return value.isNotEmpty;
      return true;
    }).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: entries.take(6).map((entry) {
        return _SummaryChip(
          label: _summaryLabel(entry.key),
          value: _summaryValue(entry.value),
        );
      }).toList(),
    );
  }

  String _summaryLabel(String key) {
    switch (key) {
      case 'total_users':
        return 'Total usuarios';
      case 'users_by_role':
        return 'Usuarios por rol';
      case 'active_users':
        return 'Activos';
      case 'inactive_users':
        return 'Inactivos';
      case 'blocked_users':
        return 'Bloqueados';
      case 'total_technicians':
        return 'Total técnicos';
      case 'pending_approval':
        return 'Pendientes';
      case 'best_rated_technicians':
        return 'Top técnicos';
      case 'average_rating':
        return 'Promedio general';
      case 'low_rated_technicians':
        return 'Baja calificación';
      case 'total_items':
        return 'Total';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  String _summaryValue(dynamic value) {
    if (value is Map) {
      return value.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
    }
    if (value is List) {
      return value.take(2).map((item) {
        if (item is Map) {
          final name = item['nombre']?.toString() ?? item['user_id']?.toString() ?? 'item';
          final rating = item['calificacion_promedio']?.toString() ?? '';
          return rating.isNotEmpty ? '$name ($rating)' : name;
        }
        return item.toString();
      }).join(' · ');
    }
    if (value is double) return value.toStringAsFixed(2);
    return value.toString();
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 240),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(4),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final _ReportType type;
  final Map<String, dynamic> row;

  const _PreviewTile({
    required this.type,
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (type) {
      _ReportType.users => row['nombre']?.toString() ?? 'Usuario',
      _ReportType.technicians => row['nombre']?.toString() ?? 'Técnico',
      _ReportType.requests =>
        row['descripcion']?.toString().isNotEmpty == true
            ? row['descripcion'].toString()
            : 'Solicitud ${row['id']}',
      _ReportType.ratings => row['rated_name']?.toString() ?? 'Calificación',
      _ReportType.operations => row['title']?.toString() ?? 'Operación',
      _ReportType.aiDiagnostics =>
        row['clasificacion_ia']?.toString() ??
            row['ai_emergency_type']?.toString() ??
            'Diagnóstico IA',
    };

    final subtitle = switch (type) {
      _ReportType.users =>
        '${row['rol'] ?? 'sin rol'} · ${row['account_state'] ?? 'activo'} · ${_formatDateValue(row['creado_en'])}',
      _ReportType.technicians =>
        '${row['especialidad'] ?? 'sin especialidad'} · ${row['estado_verificacion'] ?? 'sin estado'} · ${row['ubicacion_aproximada'] ?? 'sin ubicación'}',
      _ReportType.requests =>
        '${row['estado'] ?? 'sin estado'} · ${row['fecha'] ?? ''}',
      _ReportType.ratings =>
        '${row['rater_name'] ?? 'Usuario'} → ${row['rated_role'] ?? 'sin rol'} · ${row['puntuacion'] ?? 0} estrellas',
      _ReportType.operations => row['subtitle']?.toString() ?? '',
      _ReportType.aiDiagnostics =>
        '${row['estado'] ?? 'sin estado'} · ${row['fecha'] ?? ''}',
    };

    final trailing = switch (type) {
      _ReportType.users =>
        row['last_access']?.toString().isNotEmpty == true
            ? _formatDateValue(row['last_access'])
            : 'Sin acceso',
      _ReportType.technicians =>
        row['calificacion_promedio']?.toString() ?? '0.0',
      _ReportType.requests => row['id']?.toString() ?? '',
      _ReportType.ratings => row['zone']?.toString() ?? row['comentario']?.toString() ?? '',
      _ReportType.operations => row['value']?.toString() ?? '',
      _ReportType.aiDiagnostics => row['id']?.toString() ?? '',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Gap(4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Gap(10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateValue(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return raw?.toString() ?? '';
    final appDate = AppHelpers.toAppTime(date);
    return '${appDate.day}/${appDate.month}/${appDate.year}';
  }
}
