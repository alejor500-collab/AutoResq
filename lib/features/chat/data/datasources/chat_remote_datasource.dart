import 'dart:async';

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
      final rows = await _client
          .from(AppConstants.tableAsignaciones)
          .select('id, estado')
          .eq('emergencia_id', emergencyId)
          .order('fecha_asignacion', ascending: false);
      final assignments = (rows as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      final assignmentId = await _pickChatAssignmentId(assignments);
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

  Future<String?> _pickChatAssignmentId(
    List<Map<String, dynamic>> assignments,
  ) async {
    if (assignments.isEmpty) return null;

    for (final assignment in assignments) {
      final status = assignment['estado']?.toString();
      final assignmentId = assignment['id']?.toString();
      if (assignmentId == null || assignmentId.isEmpty) continue;
      if (status == AppConstants.assignAccepted ||
          status == AppConstants.assignEnRoute ||
          status == AppConstants.assignAttending) {
        return assignmentId;
      }
    }

    final assignmentIds = assignments
        .map((assignment) => assignment['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (assignmentIds.isEmpty) return null;

    final latestMessage = await _client
        .from(AppConstants.tableMensajes)
        .select('asignacion_id')
        .inFilter('asignacion_id', assignmentIds)
        .order('fecha_envio', ascending: false)
        .limit(1)
        .maybeSingle();
    final assignmentWithMessages = latestMessage?['asignacion_id']?.toString();
    if (assignmentWithMessages != null && assignmentWithMessages.isNotEmpty) {
      return assignmentWithMessages;
    }

    for (final assignment in assignments) {
      final status = assignment['estado']?.toString();
      final assignmentId = assignment['id']?.toString();
      if (assignmentId == null || assignmentId.isEmpty) continue;
      if (status == AppConstants.assignFinished) return assignmentId;
    }

    return assignmentIds.first;
  }

  @override
  Future<MessageModel> sendMessage({
    required String asignacionId,
    required String remitenteId,
    required String contenido,
  }) async {
    try {
      final canSend = await _canSendMessage(asignacionId);
      if (!canSend) {
        throw const ServerException(
          message:
              'El servicio ya esta cerrado. Solo puedes revisar la conversacion.',
        );
      }
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
      unawaited(_notifyMessagePush(data['id']?.toString()));
      return MessageModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<void> _notifyMessagePush(String? messageId) async {
    if (messageId == null || messageId.isEmpty) return;
    try {
      await _client.functions.invoke(
        'notify-chat-message',
        body: {'message_id': messageId},
      );
    } catch (_) {
      // El chat no debe fallar si el canal push aun no esta desplegado.
    }
  }

  Future<bool> _canSendMessage(String asignacionId) async {
    final assignment = await _client
        .from(AppConstants.tableAsignaciones)
        .select('estado, emergencia_id')
        .eq('id', asignacionId)
        .maybeSingle();
    if (assignment == null) return false;

    final assignmentStatus = assignment['estado']?.toString();
    if (assignmentStatus == AppConstants.assignFinished ||
        assignmentStatus == AppConstants.assignRejected) {
      return false;
    }

    final emergencyId = assignment['emergencia_id']?.toString();
    if (emergencyId == null || emergencyId.isEmpty) return false;
    final emergency = await _client
        .from(AppConstants.tableEmergencias)
        .select('estado')
        .eq('id', emergencyId)
        .maybeSingle();
    final emergencyStatus = emergency?['estado']?.toString();
    return emergencyStatus != AppConstants.statusCompleted &&
        emergencyStatus != AppConstants.statusCancelled;
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
      final assignmentIds = await _getParticipantAssignmentIds(userId);
      if (assignmentIds.isEmpty) return 0;

      final data = await _client
          .from(AppConstants.tableMensajes)
          .select('id')
          .inFilter('asignacion_id', assignmentIds)
          .neq('remitente_id', userId)
          .isFilter('leido_at', null);
      return (data as List).length;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<List<String>> _getParticipantAssignmentIds(String userId) async {
    final ids = <String>{};

    final driverAssignments = await _client
        .from(AppConstants.tableAsignaciones)
        .select('id, emergencias!inner(usuario_id)')
        .eq('emergencias.usuario_id', userId);
    for (final row in driverAssignments as List) {
      final assignmentId = (row as Map)['id']?.toString();
      if (assignmentId != null && assignmentId.isNotEmpty) {
        ids.add(assignmentId);
      }
    }

    final technician = await _client
        .from(AppConstants.tableTecnicos)
        .select('id')
        .eq('usuario_id', userId)
        .maybeSingle();
    final technicianId = technician?['id']?.toString();
    if (technicianId != null && technicianId.isNotEmpty) {
      final technicianAssignments = await _client
          .from(AppConstants.tableAsignaciones)
          .select('id')
          .eq('tecnico_id', technicianId);
      for (final row in technicianAssignments as List) {
        final assignmentId = (row as Map)['id']?.toString();
        if (assignmentId != null && assignmentId.isNotEmpty) {
          ids.add(assignmentId);
        }
      }
    }

    return ids.toList(growable: false);
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
