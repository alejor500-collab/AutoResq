import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/message_model.dart';

abstract class ChatRemoteDataSource {
  Future<MessageModel> sendMessage({
    required String asignacionId,
    required String remitenteId,
    required String contenido,
  });
  Future<List<MessageModel>> getMessages(String asignacionId);
  Stream<List<Map<String, dynamic>>> watchMessages(String asignacionId);
  Future<void> markAsRead(String asignacionId, String userId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final SupabaseClient _client;

  ChatRemoteDataSourceImpl(this._client);

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
          })
          .select('*, usuarios(nombre)')
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
          .select('*, usuarios(nombre)')
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
  Future<void> markAsRead(String asignacionId, String userId) async {
    try {
      await _client
          .from(AppConstants.tableMensajes)
          .update({'leido': true})
          .eq('asignacion_id', asignacionId)
          .neq('remitente_id', userId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }
}
