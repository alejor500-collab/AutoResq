import '../../domain/entities/emergency_entity.dart';

class EmergencyModel extends Emergency {
  const EmergencyModel({
    required super.id,
    required super.usuarioId,
    super.vehiculoId,
    super.tipoProblemaId,
    required super.descripcion,
    super.clasificacionIa,
    required super.estado,
    required super.fecha,
    super.driverName,
    super.lat,
    super.lng,
    super.direccion,
    super.tecnicoId,
    super.tecnicoNombre,
    super.asignacionEstado,
    super.asignacionId,
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
    String? tecnicoNombre;
    String? asignacionEstado;
    String? asignacionId;
    if (json['asignaciones'] != null) {
      final assign = json['asignaciones'] is List
          ? (json['asignaciones'] as List).firstOrNull
          : json['asignaciones'];
      if (assign != null) {
        asignacionId = assign['id'] as String?;
        asignacionEstado = assign['estado'] as String?;
        tecnicoId = assign['tecnico_id'] as String?;
        // Nested tecnico join
        if (assign['tecnicos'] != null) {
          final tech = assign['tecnicos'];
          if (tech['usuarios'] != null) {
            tecnicoNombre = tech['usuarios']['nombre'] as String?;
          }
        }
      }
    }

    return EmergencyModel(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      vehiculoId: json['vehiculo_id'] as String?,
      tipoProblemaId: json['tipo_problema_id'] as int?,
      descripcion: json['descripcion'] as String? ?? '',
      clasificacionIa: json['clasificacion_ia'] as String?,
      estado: json['estado'] as String? ?? 'pendiente',
      fecha: DateTime.parse(json['fecha'] as String),
      driverName: json['usuarios']?['nombre'] as String?,
      lat: lat,
      lng: lng,
      direccion: direccion,
      tecnicoId: tecnicoId,
      tecnicoNombre: tecnicoNombre,
      asignacionEstado: asignacionEstado,
      asignacionId: asignacionId,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'usuario_id': usuarioId,
      if (vehiculoId != null) 'vehiculo_id': vehiculoId,
      if (tipoProblemaId != null) 'tipo_problema_id': tipoProblemaId,
      'descripcion': descripcion,
      if (clasificacionIa != null) 'clasificacion_ia': clasificacionIa,
      'estado': estado,
    };
  }
}
