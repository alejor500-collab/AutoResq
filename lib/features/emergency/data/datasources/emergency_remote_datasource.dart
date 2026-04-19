import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/emergency_model.dart';

abstract class EmergencyRemoteDataSource {
  Future<EmergencyModel> createEmergency({
    required String usuarioId,
    required String descripcion,
    required double lat,
    required double lng,
    String? direccion,
    String? vehiculoId,
    int? tipoProblemaId,
    String? clasificacionIa,
  });
  Future<EmergencyModel> getEmergency(String id);
  Future<List<EmergencyModel>> getDriverEmergencies(String userId);
  Future<List<EmergencyModel>> getPendingEmergencies();
  Future<List<EmergencyModel>> getAllEmergencies();
  Future<void> updateStatus(String id, String estado);
  Future<void> assignTechnician(String emergencyId, String tecnicoId);
  Stream<List<Map<String, dynamic>>> watchEmergency(String id);
  Stream<List<Map<String, dynamic>>> watchPendingEmergencies();
  Future<List<Map<String, dynamic>>> getTiposProblema();
}

class EmergencyRemoteDataSourceImpl implements EmergencyRemoteDataSource {
  final SupabaseClient _client;

  EmergencyRemoteDataSourceImpl(this._client);

  static const _selectWithJoins =
      '*, ubicaciones(*), asignaciones(*, tecnicos(*, usuarios(nombre))), usuarios(nombre)';

  @override
  Future<EmergencyModel> createEmergency({
    required String usuarioId,
    required String descripcion,
    required double lat,
    required double lng,
    String? direccion,
    String? vehiculoId,
    int? tipoProblemaId,
    String? clasificacionIa,
  }) async {
    try {
      // 1. Insert emergency
      final emergencyData = await _client
          .from(AppConstants.tableEmergencias)
          .insert({
            'usuario_id': usuarioId,
            'descripcion': descripcion,
            if (vehiculoId != null) 'vehiculo_id': vehiculoId,
            if (tipoProblemaId != null) 'tipo_problema_id': tipoProblemaId,
            if (clasificacionIa != null) 'clasificacion_ia': clasificacionIa,
          })
          .select()
          .single();

      // 2. Insert location
      await _client.from(AppConstants.tableUbicaciones).insert({
        'emergencia_id': emergencyData['id'],
        'latitud': lat,
        'longitud': lng,
        if (direccion != null) 'direccion': direccion,
      });

      // 3. Insert historial
      await _client.from(AppConstants.tableHistorial).insert({
        'emergencia_id': emergencyData['id'],
        'actor_id': usuarioId,
        'tipo_evento': 'creacion',
        'descripcion': 'Emergencia creada',
      });

      // 4. Fetch with joins
      return await getEmergency(emergencyData['id']);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<EmergencyModel> getEmergency(String id) async {
    try {
      final data = await _client
          .from(AppConstants.tableEmergencias)
          .select(_selectWithJoins)
          .eq('id', id)
          .single();
      return EmergencyModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<EmergencyModel>> getDriverEmergencies(String userId) async {
    try {
      final data = await _client
          .from(AppConstants.tableEmergencias)
          .select(_selectWithJoins)
          .eq('usuario_id', userId)
          .order('fecha', ascending: false);
      return (data as List)
          .map((e) => EmergencyModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<EmergencyModel>> getPendingEmergencies() async {
    try {
      final data = await _client
          .from(AppConstants.tableEmergencias)
          .select(_selectWithJoins)
          .eq('estado', AppConstants.statusPending)
          .order('fecha', ascending: false);
      return (data as List)
          .map((e) => EmergencyModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<EmergencyModel>> getAllEmergencies() async {
    try {
      final data = await _client
          .from(AppConstants.tableEmergencias)
          .select(_selectWithJoins)
          .order('fecha', ascending: false);
      return (data as List)
          .map((e) => EmergencyModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> updateStatus(String id, String estado) async {
    try {
      await _client
          .from(AppConstants.tableEmergencias)
          .update({'estado': estado})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> assignTechnician(String emergencyId, String tecnicoId) async {
    try {
      // Create assignment
      await _client.from(AppConstants.tableAsignaciones).insert({
        'emergencia_id': emergencyId,
        'tecnico_id': tecnicoId,
        'estado': AppConstants.assignAccepted,
      });

      // Update emergency status
      await _client
          .from(AppConstants.tableEmergencias)
          .update({'estado': AppConstants.statusInProgress})
          .eq('id', emergencyId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchEmergency(String id) {
    return _client
        .from(AppConstants.tableEmergencias)
        .stream(primaryKey: ['id'])
        .eq('id', id);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchPendingEmergencies() {
    return _client
        .from(AppConstants.tableEmergencias)
        .stream(primaryKey: ['id'])
        .eq('estado', AppConstants.statusPending);
  }

  @override
  Future<List<Map<String, dynamic>>> getTiposProblema() async {
    try {
      final data = await _client
          .from(AppConstants.tableTiposProblema)
          .select()
          .order('id');
      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }
}
