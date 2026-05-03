import '../../domain/entities/message_entity.dart';

class MessageModel extends ChatMessage {
  const MessageModel({
    required super.id,
    required super.asignacionId,
    required super.remitenteId,
    required super.contenido,
    super.leido,
    super.entregadoAt,
    super.leidoAt,
    required super.fechaEnvio,
    super.remitenteNombre,
    super.remitenteAvatarUrl,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      asignacionId: json['asignacion_id'] as String,
      remitenteId: json['remitente_id'] as String,
      contenido: json['contenido'] as String,
      leido: json['leido'] as bool? ?? false,
      entregadoAt: json['entregado_at'] == null
          ? null
          : DateTime.parse(json['entregado_at'] as String),
      leidoAt: json['leido_at'] == null
          ? null
          : DateTime.parse(json['leido_at'] as String),
      fechaEnvio: DateTime.parse(json['fecha_envio'] as String),
      remitenteNombre: json['usuarios']?['nombre'] as String?,
      remitenteAvatarUrl: json['usuarios']?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'asignacion_id': asignacionId,
        'remitente_id': remitenteId,
        'contenido': contenido,
        if (entregadoAt != null) 'entregado_at': entregadoAt!.toIso8601String(),
        if (leidoAt != null) 'leido_at': leidoAt!.toIso8601String(),
      };
}
