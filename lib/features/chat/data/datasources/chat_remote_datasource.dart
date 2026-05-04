import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/message_model.dart';

abstract class ChatRemoteDataSource {
  Future<String> getAssignmentIdForEmergency(String emergencyId);
  Future<MessageModel> sendMessage({
    required String asignacionId,
    required String remitenteId,
    required String contenido,
  });
  Future<List<MessageModel>> getMessages(String asignacionId);
  Stream<List<Map<String, dynamic>>> watchMessages(String asignacionId);
  Future<int> getUnreadMessageCount(String userId);
  Future<void> markIncomingAsDelivered(String asignacionId, String userId);
  Future<void> markIncomingAsRead(String asignacionId, String userId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final SupabaseClient _client;

  ChatRemoteDataSourceImpl(this._client);

  @override
  Future<String> getAssignmentIdForEmergency(String emergencyId) async {
    try {
      final data = await _client
          .from(AppConstants.tableAsignaciones)
          .select('id')
          .eq('emergencia_id', emergencyId)
          .order('fecha_asignacion', ascending: false)
          .limit(1)
          .maybeSingle();
      final assignmentId = data?['id']?.toString();
      if (assignmentId == null || assignmentId.isEmpty) {
        throw const ServerException(
          message: 'El chat estara disponible cuando un tecnico acepte.',
        );
      }
      return assignmentId;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<MessageModel> sendMessage({
    required String asignacionId,
    required String remitenteId,
    required String contenido,
  }) async {
    try {
      final data = await _client
          .from(AppConstants.tableMensajes)
          .insert({
            'asignacion_id': asignacionId,
            'remitente_id': remitenteId,
            'contenido': contenido,
            'entregado_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('*, usuarios!remitente_id(nombre, avatar_url)')
          .single();
      return MessageModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<MessageModel>> getMessages(String asignacionId) async {
    try {
      final data = await _client
          .from(AppConstants.tableMensajes)
          .select('*, usuarios!remitente_id(nombre, avatar_url)')
          .eq('asignacion_id', asignacionId)
          .order('fecha_envio', ascending: true);
      return (data as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchMessages(String asignacionId) {
    return _client
        .from(AppConstants.tableMensajes)
        .stream(primaryKey: ['id'])
        .eq('asignacion_id', asignacionId)
        .order('fecha_envio', ascending: true);
  }

  @override
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final data = await _client
          .from(AppConstants.tableMensajes)
          .select('id')
          .neq('remitente_id', userId)
          .isFilter('leido_at', null);
      return (data as List).length;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> markIncomingAsDelivered(String asignacionId, String userId) async {
    try {
      await _client
          .from(AppConstants.tableMensajes)
          .update({'entregado_at': DateTime.now().toUtc().toIso8601String()})
          .eq('asignacion_id', asignacionId)
          .neq('remitente_id', userId)
          .isFilter('entregado_at', null);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> markIncomingAsRead(String asignacionId, String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _client
          .from(AppConstants.tableMensajes)
          .update({
            'leido': true,
            'entregado_at': now,
            'leido_at': now,
          })
          .eq('asignacion_id', asignacionId)
          .neq('remitente_id', userId)
          .isFilter('leido_at', null);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }
}
