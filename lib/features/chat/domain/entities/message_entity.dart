import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String asignacionId;
  final String remitenteId;
  final String contenido;
  final bool leido;
  final DateTime? entregadoAt;
  final DateTime? leidoAt;
  final DateTime fechaEnvio;
  // Joined data
  final String? remitenteNombre;
  final String? remitenteAvatarUrl;

  const ChatMessage({
    required this.id,
    required this.asignacionId,
    required this.remitenteId,
    required this.contenido,
    this.leido = false,
    this.entregadoAt,
    this.leidoAt,
    required this.fechaEnvio,
    this.remitenteNombre,
    this.remitenteAvatarUrl,
  });

  bool get isDelivered => entregadoAt != null || isRead;
  bool get isRead => leido || leidoAt != null;

  @override
  List<Object?> get props => [
        id,
        asignacionId,
        remitenteId,
        contenido,
        leido,
        entregadoAt,
        leidoAt,
        fechaEnvio,
        remitenteNombre,
        remitenteAvatarUrl,
      ];
}
