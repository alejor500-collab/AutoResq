import '../../domain/entities/message_entity.dart';

class MessageModel extends ChatMessage {
  const MessageModel({
    required super.id,
    required super.asignacionId,
    required super.remitenteId,
    required super.contenido,
    super.leido,
    required super.fechaEnvio,
    super.remitenteNombre,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      asignacionId: json['asignacion_id'] as String,
      remitenteId: json['remitente_id'] as String,
      contenido: json['contenido'] as String,
      leido: json['leido'] as bool? ?? false,
      fechaEnvio: DateTime.parse(json['fecha_envio'] as String),
      remitenteNombre: json['usuarios']?['nombre'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'asignacion_id': asignacionId,
        'remitente_id': remitenteId,
        'contenido': contenido,
      };
}
