import '../../domain/entities/emergency_entity.dart';

class EmergencyModel extends Emergency {
  const EmergencyModel({
    required super.id,
    required super.usuarioId,
    super.vehiculoId,
    super.tipoProblemaId,
    required super.descripcion,
    super.clasificacionIa,
    super.aiEmergencyType,
    super.aiPriority,
    super.aiUserMessage,
    super.aiSafetyRecommendation,
    super.aiTechnicianSummary,
    super.aiDetectedRisks,
    super.aiRequiresImmediateAttention,
    super.aiConfidence,
    super.aiAnalysisStatus,
    super.aiAnalyzedAt,
    required super.estado,
    required super.fecha,
    super.driverName,
    super.driverPhone,
    super.lat,
    super.lng,
    super.direccion,
    super.tecnicoId,
    super.tecnicoUsuarioId,
    super.tecnicoNombre,
    super.tecnicoPhone,
    super.tecnicoSpecialty,
    super.tecnicoRating,
    super.asignacionEstado,
    super.asignacionId,
    super.asignacionFecha,
    super.priceSnapshot,
  });

  /// Parse from Supabase row (emergencias table with optional joins)
  factory EmergencyModel.fromJson(Map<String, dynamic> json) {
    // Location may come from joined `ubicaciones` table
    double? lat;
    double? lng;
    String? direccion;
    if (json['ubicaciones'] != null) {
      final loc = json['ubicaciones'] is List
          ? (json['ubicaciones'] as List).firstOrNull
          : json['ubicaciones'];
      if (loc != null) {
        lat = (loc['latitud'] as num?)?.toDouble();
        lng = (loc['longitud'] as num?)?.toDouble();
        direccion = loc['direccion'] as String?;
      }
    }
    lat ??= (json['latitud'] as num?)?.toDouble();
    lng ??= (json['longitud'] as num?)?.toDouble();
    direccion ??= json['direccion'] as String?;

    // Assignment may come from joined `asignaciones` table
    String? tecnicoId;
    String? tecnicoUsuarioId;
    String? tecnicoNombre;
    String? tecnicoPhone;
    String? tecnicoSpecialty;
    double? tecnicoRating;
    String? asignacionEstado;
    String? asignacionId;
    DateTime? asignacionFecha;
    if (json['asignaciones'] != null) {
      final assign = _pickAssignment(json['asignaciones']);
      if (assign != null) {
        asignacionId = assign['id'] as String?;
        asignacionEstado = assign['estado'] as String?;
        tecnicoId = assign['tecnico_id'] as String?;
        asignacionFecha = _parseDate(assign['fecha_asignacion']);
        // Nested tecnico join
        if (assign['tecnicos'] != null) {
          final tech = _firstMap(assign['tecnicos']);
          tecnicoUsuarioId = tech['usuario_id'] as String?;
          tecnicoSpecialty = tech['especialidad'] as String?;
          tecnicoRating = (tech['calificacion_promedio'] as num?)?.toDouble();
          final techUser = _firstMap(tech['usuarios']);
          if (techUser.isNotEmpty) {
            tecnicoNombre = techUser['nombre'] as String?;
            tecnicoPhone = techUser['telefono'] as String?;
          }
        }
      }
    }

    Map<String, dynamic>? priceSnapshot;
    if (json['emergency_price_snapshots'] != null) {
      final snapshotRow = json['emergency_price_snapshots'] is List
          ? (json['emergency_price_snapshots'] as List).firstOrNull
          : json['emergency_price_snapshots'];
      if (snapshotRow is Map && snapshotRow['snapshot'] is Map) {
        priceSnapshot =
            Map<String, dynamic>.from(snapshotRow['snapshot'] as Map);
      }
    }

    return EmergencyModel(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      vehiculoId: json['vehiculo_id'] as String?,
      tipoProblemaId: json['tipo_problema_id'] as int?,
      descripcion: json['descripcion'] as String? ?? '',
      clasificacionIa: json['clasificacion_ia'] as String?,
      aiEmergencyType: json['ai_emergency_type'] as String?,
      aiPriority: json['ai_priority'] as String?,
      aiUserMessage: json['ai_user_message'] as String?,
      aiSafetyRecommendation: json['ai_safety_recommendation'] as String?,
      aiTechnicianSummary: json['ai_technician_summary'] as String?,
      aiDetectedRisks:
          (json['ai_detected_risks'] as List?)?.cast<String>() ?? const [],
      aiRequiresImmediateAttention:
          json['ai_requires_immediate_attention'] as bool?,
      aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
      aiAnalysisStatus: json['ai_analysis_status'] as String?,
      aiAnalyzedAt: json['ai_analyzed_at'] == null
          ? null
          : DateTime.parse(json['ai_analyzed_at'] as String),
      estado: json['estado'] as String? ?? 'pendiente',
      fecha: DateTime.parse(json['fecha'] as String),
      driverName: _firstMap(json['usuarios'])['nombre'] as String?,
      driverPhone: _firstMap(json['usuarios'])['telefono'] as String?,
      lat: lat,
      lng: lng,
      direccion: direccion,
      tecnicoId: tecnicoId,
      tecnicoUsuarioId: tecnicoUsuarioId,
      tecnicoNombre: tecnicoNombre,
      tecnicoPhone: tecnicoPhone,
      tecnicoSpecialty: tecnicoSpecialty,
      tecnicoRating: tecnicoRating,
      asignacionEstado: asignacionEstado,
      asignacionId: asignacionId,
      asignacionFecha: asignacionFecha,
      priceSnapshot: priceSnapshot,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'usuario_id': usuarioId,
      if (vehiculoId != null) 'vehiculo_id': vehiculoId,
      if (tipoProblemaId != null) 'tipo_problema_id': tipoProblemaId,
      'descripcion': descripcion,
      if (clasificacionIa != null) 'clasificacion_ia': clasificacionIa,
      if (aiEmergencyType != null) 'ai_emergency_type': aiEmergencyType,
      if (aiPriority != null) 'ai_priority': aiPriority,
      if (aiUserMessage != null) 'ai_user_message': aiUserMessage,
      if (aiSafetyRecommendation != null)
        'ai_safety_recommendation': aiSafetyRecommendation,
      if (aiTechnicianSummary != null)
        'ai_technician_summary': aiTechnicianSummary,
      if (aiDetectedRisks.isNotEmpty) 'ai_detected_risks': aiDetectedRisks,
      if (aiRequiresImmediateAttention != null)
        'ai_requires_immediate_attention': aiRequiresImmediateAttention,
      if (aiConfidence != null) 'ai_confidence': aiConfidence,
      if (aiAnalysisStatus != null) 'ai_analysis_status': aiAnalysisStatus,
      if (aiAnalyzedAt != null)
        'ai_analyzed_at': aiAnalyzedAt!.toIso8601String(),
      'estado': estado,
    };
  }

  static Map<String, dynamic> _firstMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const {};
  }

  static Map<String, dynamic>? _pickAssignment(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is! List || value.isEmpty) return null;

    final rows = value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (rows.isEmpty) return null;

    rows.sort((a, b) {
      final rankCompare =
          _assignmentRank(b['estado'] as String?).compareTo(
        _assignmentRank(a['estado'] as String?),
      );
      if (rankCompare != 0) return rankCompare;

      final aDate = _parseDate(a['fecha_asignacion']);
      final bDate = _parseDate(b['fecha_asignacion']);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return rows.first;
  }

  static int _assignmentRank(String? status) {
    return switch (status) {
      'finalizada' => 5,
      'atendiendo' => 4,
      'en_ruta' => 3,
      'aceptada' => 2,
      'rechazada' => 1,
      _ => 0,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
