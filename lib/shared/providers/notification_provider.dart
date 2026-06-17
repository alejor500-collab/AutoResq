import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/helpers.dart';
import 'auth_provider.dart';

class AppNotification {
  final String id;
  final String type;
  final String message;
  final bool read;
  final String? referenceId;
  final DateTime createdAt;
  final RequestNotificationSummary? requestSummary;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.read,
    this.referenceId,
    required this.createdAt,
    this.requestSummary,
  });

  factory AppNotification.fromJson(
    Map<String, dynamic> json, {
    RequestNotificationSummary? requestSummary,
  }) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['tipo']?.toString() ?? 'general',
      message: json['mensaje']?.toString() ?? '',
      read: json['leida'] == true,
      referenceId: json['referencia_id']?.toString(),
      createdAt: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
          DateTime.now(),
      requestSummary: requestSummary,
    );
  }

  String get title {
    return switch (type) {
      'nueva_solicitud' => 'Nueva solicitud',
      'nuevo_mensaje' => 'Nuevo mensaje',
      'solicitud_cancelada' => 'Solicitud cancelada',
      'tecnico_cancelo' => 'Tecnico cancelado',
      'solicitud_aceptada' => 'Solicitud aceptada',
      'tecnico_en_ruta' => 'Tecnico en tu ubicacion',
      'servicio_finalizado' => 'Servicio finalizado',
      _ => 'Notificacion',
    };
  }

  String get displayTitle {
    final summary = requestSummary;
    if (type == 'nueva_solicitud' && summary != null) {
      if (!summary.isAvailable) return 'Solicitud no disponible';
      return summary.driverName == null
          ? 'Nueva solicitud'
          : '${summary.driverName} necesita asistencia';
    }
    return title;
  }

  String get displayMessage {
    final summary = requestSummary;
    if (type == 'nueva_solicitud' && summary != null) {
      final parts = [
        summary.serviceName ?? 'Servicio',
        if (summary.address != null) summary.address!,
      ];
      final detail = parts.join(' - ');
      if (!summary.isAvailable) {
        return '$detail. ${summary.statusLabel}.';
      }
      return detail;
    }
    return message;
  }

  String? get statusLabel => requestSummary?.statusLabel;
  bool get isActionable => type != 'nueva_solicitud' ||
      requestSummary == null ||
      requestSummary!.isAvailable;
  String get timeLabel => AppHelpers.formatDateTime(createdAt);
  String? get requestTimeLabel => requestSummary == null
      ? null
      : 'Solicitud: ${AppHelpers.formatDateTime(requestSummary!.createdAt)}';
}

class RequestNotificationSummary {
  final String emergencyId;
  final String? driverName;
  final String? serviceName;
  final String? address;
  final DateTime createdAt;
  final String status;
  final String? assignmentStatus;

  const RequestNotificationSummary({
    required this.emergencyId,
    required this.createdAt,
    required this.status,
    this.driverName,
    this.serviceName,
    this.address,
    this.assignmentStatus,
  });

  bool get isAvailable => status == AppConstants.statusPending &&
      (assignmentStatus == null ||
          assignmentStatus == AppConstants.assignRejected);

  String get statusLabel {
    if (isAvailable) return 'Disponible';
    if (assignmentStatus == AppConstants.assignFinished) {
      return 'Solicitud finalizada';
    }
    if (assignmentStatus == AppConstants.assignAccepted ||
        assignmentStatus == AppConstants.assignEnRoute ||
        assignmentStatus == AppConstants.assignAttending) {
      return 'Ya fue tomada por otro tecnico';
    }
    return switch (status) {
      AppConstants.statusCompleted => 'Solicitud finalizada',
      AppConstants.statusCancelled => 'Solicitud cancelada',
      AppConstants.statusAttended => 'Servicio en atencion',
      AppConstants.statusInProgress => 'Ya fue tomada por otro tecnico',
      _ => 'Solicitud no disponible',
    };
  }
}

final notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) async* {
  final user = ref.watch(authNotifierProvider).value ??
      ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    yield const [];
    return;
  }

  final client = ref.read(supabaseClientProvider);
  Future<List<AppNotification>> fetch() async {
    final rows = await client
        .from(AppConstants.tableNotificaciones)
        .select()
        .eq('usuario_id', user.id)
        .order('fecha', ascending: false)
        .limit(50);
    final notificationRows =
        (rows as List).cast<Map>().map(Map<String, dynamic>.from).toList();
    final summaries = await _fetchRequestSummaries(client, notificationRows);
    return notificationRows
        .map(
          (row) => AppNotification.fromJson(
            row,
            requestSummary: summaries[row['referencia_id']?.toString()],
          ),
        )
        .toList();
  }

  yield await fetch();
  yield* client
      .from(AppConstants.tableNotificaciones)
      .stream(primaryKey: ['id'])
      .eq('usuario_id', user.id)
      .order('fecha', ascending: false)
      .asyncMap((_) => fetch());
});

Future<Map<String, RequestNotificationSummary>> _fetchRequestSummaries(
  dynamic client,
  List<Map<String, dynamic>> notifications,
) async {
  final ids = notifications
      .where((row) => row['tipo']?.toString() == 'nueva_solicitud')
      .map((row) => row['referencia_id']?.toString())
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
  if (ids.isEmpty) return const {};

  final rows = await _fetchEmergencySummaryRows(client, ids);

  return {
    for (final raw in rows)
      if (raw is Map)
        raw['id']?.toString() ?? '': _summaryFromEmergencyRow(
          Map<String, dynamic>.from(raw),
        ),
  }..remove('');
}

Future<List<dynamic>> _fetchEmergencySummaryRows(
  dynamic client,
  List<String> ids,
) async {
  try {
    final rows = await client
        .from(AppConstants.tableEmergencias)
        .select(
          'id, estado, fecha, clasificacion_ia, ai_emergency_type, '
          'usuarios!usuario_id(nombre), ubicaciones(direccion), '
          'emergency_price_snapshots(snapshot), asignaciones(estado)',
        )
        .inFilter('id', ids);
    return rows as List;
  } catch (_) {
    final rows = await client
        .from(AppConstants.tableEmergencias)
        .select(
          'id, estado, fecha, clasificacion_ia, ai_emergency_type, '
          'usuarios!usuario_id(nombre), ubicaciones(direccion), '
          'asignaciones(estado)',
        )
        .inFilter('id', ids);
    return rows as List;
  }
}

RequestNotificationSummary _summaryFromEmergencyRow(
  Map<String, dynamic> row,
) {
  final snapshotRow = _firstMap(row['emergency_price_snapshots']);
  final snapshot = snapshotRow['snapshot'] is Map
      ? Map<String, dynamic>.from(snapshotRow['snapshot'] as Map)
      : const <String, dynamic>{};
  final assignment = _currentAssignment(row['asignaciones']);

  return RequestNotificationSummary(
    emergencyId: row['id']?.toString() ?? '',
    createdAt: DateTime.tryParse(row['fecha']?.toString() ?? '') ??
        DateTime.now(),
    status: row['estado']?.toString() ?? AppConstants.statusPending,
    assignmentStatus: assignment?['estado']?.toString(),
    driverName: _blankToNull(_firstMap(row['usuarios'])['nombre']?.toString()),
    serviceName: _blankToNull(
      snapshot['service_name']?.toString() ??
          row['ai_emergency_type']?.toString() ??
          row['clasificacion_ia']?.toString(),
    ),
    address: _blankToNull(_firstMap(row['ubicaciones'])['direccion']?.toString()),
  );
}

Map<String, dynamic> _firstMap(Object? value) {
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

Map<String, dynamic>? _currentAssignment(Object? value) {
  final assignments = value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : value is Map
          ? [Map<String, dynamic>.from(value)]
          : const <Map<String, dynamic>>[];
  if (assignments.isEmpty) return null;
  const active = {
    AppConstants.assignAccepted,
    AppConstants.assignEnRoute,
    AppConstants.assignAttending,
    AppConstants.assignFinished,
  };
  for (final assignment in assignments) {
    if (active.contains(assignment['estado']?.toString())) {
      return assignment;
    }
  }
  return assignments.first;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull;
  if (notifications == null) return 0;
  return notifications.where((notification) => !notification.read).length;
});

final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(ref);
});

class NotificationActions {
  final Ref _ref;

  NotificationActions(this._ref);

  Future<void> markAllRead() async {
    final user = _ref.read(authNotifierProvider).value ??
        _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await _ref
        .read(supabaseClientProvider)
        .from(AppConstants.tableNotificaciones)
        .update({'leida': true})
        .eq('usuario_id', user.id)
        .eq('leida', false);
  }
}
