import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String asignacionId;
  final String remitenteId;
  final String contenido;
  final bool leido;
  final DateTime fechaEnvio;
  // Joined data
  final String? remitenteNombre;

  const ChatMessage({
    required this.id,
    required this.asignacionId,
    required this.remitenteId,
    required this.contenido,
    this.leido = false,
    required this.fechaEnvio,
    this.remitenteNombre,
  });

  @override
  List<Object?> get props =>
      [id, asignacionId, remitenteId, contenido, leido, fechaEnvio];
}
