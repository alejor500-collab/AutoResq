import 'package:equatable/equatable.dart';

class AiAnalysis extends Equatable {
  final String tipo;
  final String sugerencia;
  final String descripcionBreve;

  const AiAnalysis({
    required this.tipo,
    required this.sugerencia,
    required this.descripcionBreve,
  });

  @override
  List<Object?> get props => [tipo, sugerencia, descripcionBreve];
}

class Emergency extends Equatable {
  final String id;
  final String usuarioId;
  final String? vehiculoId;
  final int? tipoProblemaId;
  final String descripcion;
  final String? clasificacionIa;
  final String estado; // pendiente | en_proceso | atendida | finalizada | cancelada
  final DateTime fecha;

  // Joined data (not in emergencias table directly)
  final String? driverName;
  final double? lat;
  final double? lng;
  final String? direccion;
  final String? tecnicoId;
  final String? tecnicoNombre;
  final String? asignacionEstado; // aceptada | en_ruta | atendiendo | finalizada | rechazada
  final String? asignacionId;

  const Emergency({
    required this.id,
    required this.usuarioId,
    this.vehiculoId,
    this.tipoProblemaId,
    required this.descripcion,
    this.clasificacionIa,
    required this.estado,
    required this.fecha,
    this.driverName,
    this.lat,
    this.lng,
    this.direccion,
    this.tecnicoId,
    this.tecnicoNombre,
    this.asignacionEstado,
    this.asignacionId,
  });

  bool get hasTechnician => tecnicoId != null;

  Emergency copyWith({
    String? id,
    String? usuarioId,
    String? vehiculoId,
    int? tipoProblemaId,
    String? descripcion,
    String? clasificacionIa,
    String? estado,
    DateTime? fecha,
    String? driverName,
    double? lat,
    double? lng,
    String? direccion,
    String? tecnicoId,
    String? tecnicoNombre,
    String? asignacionEstado,
    String? asignacionId,
  }) {
    return Emergency(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      vehiculoId: vehiculoId ?? this.vehiculoId,
      tipoProblemaId: tipoProblemaId ?? this.tipoProblemaId,
      descripcion: descripcion ?? this.descripcion,
      clasificacionIa: clasificacionIa ?? this.clasificacionIa,
      estado: estado ?? this.estado,
      fecha: fecha ?? this.fecha,
      driverName: driverName ?? this.driverName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      direccion: direccion ?? this.direccion,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      tecnicoNombre: tecnicoNombre ?? this.tecnicoNombre,
      asignacionEstado: asignacionEstado ?? this.asignacionEstado,
      asignacionId: asignacionId ?? this.asignacionId,
    );
  }

  @override
  List<Object?> get props => [
        id, usuarioId, vehiculoId, tipoProblemaId, descripcion,
        clasificacionIa, estado, fecha, lat, lng, direccion,
        tecnicoId, tecnicoNombre, asignacionEstado, asignacionId,
      ];
}
