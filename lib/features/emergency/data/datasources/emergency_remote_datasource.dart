import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/technician_specialties.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/emergency_ai_analysis_model.dart';
import '../models/emergency_model.dart';
import '../models/emergency_pricing_model.dart';

abstract class EmergencyRemoteDataSource {
  Future<EmergencyModel> createEmergency({
    required String usuarioId,
    required String descripcion,
    required double lat,
    required double lng,
    String? direccion,
    String? vehiculoId,
    int? tipoProblemaId,
    EmergencyAiAnalysisModel? aiAnalysis,
    String aiAnalysisStatus = 'pending',
    EmergencyPriceQuote? priceQuote,
  });
  Future<void> createTechnicianOffer(String emergencyId);
  Future<void> acceptTechnicianOffer(String offerId);
  Future<List<Map<String, dynamic>>> getTechnicianOffers(String emergencyId);
  Stream<List<Map<String, dynamic>>> watchTechnicianOfferRows(
    String emergencyId,
  );
  Future<EmergencyAiAnalysisModel> analyzeEmergency({
    required String description,
    double? lat,
    double? lng,
    String? direccion,
  });
  Future<EmergencyModel> getEmergency(String id);
  Future<EmergencyModel?> getActiveDriverEmergency(String userId);
  Future<EmergencyModel?> getActiveTechnicianEmergency(String technicianUserId);
  Future<List<EmergencyModel>> getDriverEmergencies(String userId);
  Future<List<EmergencyModel>> getTechnicianEmergencies(
    String technicianUserId,
  );
  Future<List<EmergencyModel>> getPendingEmergencies();
  Future<List<EmergencyModel>> getPendingEmergenciesForSpecialty(
    String? specialty,
  );
  Future<List<EmergencyModel>> getAllEmergencies();
  Future<void> updateStatus(String id, String estado);
  Future<void> cancelTechnicianService(String emergencyId);
  Future<void> assignTechnician(String emergencyId, String technicianUserId);
  Future<bool> hasPendingRating({
    required String userId,
    required String role,
  });
  Future<Map<String, dynamic>?> getPendingRating({
    required String userId,
    required String role,
  });
  Stream<List<Map<String, dynamic>>> watchEmergency(String id);
  Stream<List<Map<String, dynamic>>> watchPendingEmergencies();
  Future<List<Map<String, dynamic>>> getTiposProblema();
}

class EmergencyRemoteDataSourceImpl implements EmergencyRemoteDataSource {
  final SupabaseClient _client;

  EmergencyRemoteDataSourceImpl(this._client);

  static const _selectWithJoins =
      '*, ubicaciones(*), asignaciones(*, tecnicos(id, usuario_id, especialidad, calificacion_promedio, usuarios!usuario_id(id, nombre, telefono))), usuarios!usuario_id(id, nombre, telefono), emergency_price_snapshots(*)';
  static const _selectWithoutPriceSnapshots =
      '*, ubicaciones(*), asignaciones(*, tecnicos(id, usuario_id, especialidad, calificacion_promedio, usuarios!usuario_id(id, nombre, telefono))), usuarios!usuario_id(id, nombre, telefono)';

  @override
  Future<EmergencyModel> createEmergency({
    required String usuarioId,
    required String descripcion,
    required double lat,
    required double lng,
    String? direccion,
    String? vehiculoId,
    int? tipoProblemaId,
    EmergencyAiAnalysisModel? aiAnalysis,
    String aiAnalysisStatus = 'pending',
    EmergencyPriceQuote? priceQuote,
  }) async {
    try {
      final resolvedTipoProblemaId =
          tipoProblemaId ?? _tipoProblemaIdForAiType(aiAnalysis?.emergencyType);
      final baseInsertData = {
        'usuario_id': usuarioId,
        'descripcion': descripcion,
        if (vehiculoId != null) 'vehiculo_id': vehiculoId,
        if (resolvedTipoProblemaId != null)
          'tipo_problema_id': resolvedTipoProblemaId,
      };
      final insertData = {
        ...baseInsertData,
        if (aiAnalysis != null)
          ...aiAnalysis.toEmergencyInsertJson(status: aiAnalysisStatus)
        else
          'ai_analysis_status': aiAnalysisStatus,
      };

      // 1. Insert emergency
      Map<String, dynamic> emergencyData;
      try {
        emergencyData = await _client
            .from(AppConstants.tableEmergencias)
            .insert(insertData)
            .select()
            .single();
      } on PostgrestException catch (e) {
        if (!_looksLikeMissingAiColumns(e)) rethrow;
        emergencyData = await _client
            .from(AppConstants.tableEmergencias)
            .insert(baseInsertData)
            .select()
            .single();
      }

      // 2. Insert location
      await _client.from(AppConstants.tableUbicaciones).insert({
        'emergencia_id': emergencyData['id'],
        'latitud': lat,
        'longitud': lng,
        if (direccion != null) 'direccion': direccion,
      });

      // 3. Freeze the price used at creation. Future tariff edits must not
      // change an emergency that is already in progress.
      if (priceQuote != null) {
        try {
          await _client
              .from(AppConstants.tableEmergencyPriceSnapshots)
              .insert(priceQuote.toSnapshotInsertJson(emergencyData['id']));
        } on PostgrestException catch (e) {
          if (!_looksLikeMissingPricingSchema(e)) rethrow;
        }
      }

      // 4. Insert historial
      await _client.from(AppConstants.tableHistorial).insert({
        'emergencia_id': emergencyData['id'],
        'actor_id': usuarioId,
        'tipo_evento': 'creacion',
        'descripcion': 'Emergencia creada',
      });

      unawaited(
        _notifyTechniciansAboutEmergency(emergencyData['id']?.toString()),
      );

      // 5. Fetch with joins
      return await getEmergency(emergencyData['id']);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  Future<void> _notifyTechniciansAboutEmergency(String? emergencyId) async {
    if (emergencyId == null || emergencyId.isEmpty) return;
    try {
      await _client.functions.invoke(
        'notify-new-emergency',
        body: {'emergency_id': emergencyId},
      );
    } catch (_) {
      // La emergencia no debe fallar si el canal push aun no esta desplegado.
    }
  }

  @override
  Future<EmergencyAiAnalysisModel> analyzeEmergency({
    required String description,
    double? lat,
    double? lng,
    String? direccion,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'analyze-emergency',
        body: {
          'description': description,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (direccion != null && direccion.trim().isNotEmpty)
            'location': direccion,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const ServerException(message: 'Respuesta de IA invalida');
      }

      return EmergencyAiAnalysisModel.fromJson(
        Map<String, dynamic>.from(data),
      );
    } on FunctionException catch (e) {
      throw ServerException(
        message: e.toString(),
      );
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
      if (_looksLikeMissingPricingSchema(e)) {
        final data = await _client
            .from(AppConstants.tableEmergencias)
            .select(_selectWithoutPriceSnapshots)
            .eq('id', id)
            .single();
        return EmergencyModel.fromJson(data);
      }
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<EmergencyModel?> getActiveDriverEmergency(String userId) async {
    try {
      final data = await _client
          .from(AppConstants.tableEmergencias)
          .select(_selectWithJoins)
          .eq('usuario_id', userId)
          .inFilter('estado', [
            AppConstants.statusPending,
            AppConstants.statusInProgress,
            AppConstants.statusAttended,
          ])
          .order('fecha', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return EmergencyModel.fromJson(data);
    } on PostgrestException catch (e) {
      if (_looksLikeMissingPricingSchema(e)) {
        final data = await _client
            .from(AppConstants.tableEmergencias)
            .select(_selectWithoutPriceSnapshots)
            .eq('usuario_id', userId)
            .inFilter('estado', [
              AppConstants.statusPending,
              AppConstants.statusInProgress,
              AppConstants.statusAttended,
            ])
            .order('fecha', ascending: false)
            .limit(1)
            .maybeSingle();
        if (data == null) return null;
        return EmergencyModel.fromJson(data);
      }
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<EmergencyModel?> getActiveTechnicianEmergency(
    String technicianUserId,
  ) async {
    try {
      final technician = await _client
          .from(AppConstants.tableTecnicos)
          .select('id')
          .eq('usuario_id', technicianUserId)
          .maybeSingle();
      final technicianProfileId = technician?['id']?.toString();
      if (technicianProfileId == null || technicianProfileId.isEmpty) {
        return null;
      }

      final rows = await _client
          .from(AppConstants.tableAsignaciones)
          .select('emergencia_id')
          .eq('tecnico_id', technicianProfileId)
          .inFilter('estado', [
            AppConstants.assignAccepted,
            AppConstants.assignEnRoute,
            AppConstants.assignAttending,
          ])
          .order('fecha_asignacion', ascending: false)
          .limit(5);

      for (final raw in rows as List) {
        final emergencyId = (raw as Map)['emergencia_id']?.toString();
        if (emergencyId == null || emergencyId.isEmpty) continue;
        final emergency = await getEmergency(emergencyId);
        if ([
          AppConstants.statusPending,
          AppConstants.statusInProgress,
          AppConstants.statusAttended,
        ].contains(emergency.estado)) {
          return emergency;
        }
      }
      return null;
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
      if (_looksLikeMissingPricingSchema(e)) {
        final data = await _client
            .from(AppConstants.tableEmergencias)
            .select(_selectWithoutPriceSnapshots)
            .eq('usuario_id', userId)
            .order('fecha', ascending: false);
        return (data as List)
            .map((e) => EmergencyModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<EmergencyModel>> getTechnicianEmergencies(
    String technicianUserId,
  ) async {
    try {
      final technician = await _client
          .from(AppConstants.tableTecnicos)
          .select('id')
          .eq('usuario_id', technicianUserId)
          .maybeSingle();
      final technicianProfileId = technician?['id']?.toString();
      if (technicianProfileId == null || technicianProfileId.isEmpty) {
        return const [];
      }

      final rows = await _client
          .from(AppConstants.tableAsignaciones)
          .select('emergencia_id')
          .eq('tecnico_id', technicianProfileId)
          .order('fecha_asignacion', ascending: false);

      final emergencies = <EmergencyModel>[];
      final seen = <String>{};
      for (final raw in rows as List) {
        final emergencyId = (raw as Map)['emergencia_id']?.toString();
        if (emergencyId == null || emergencyId.isEmpty || !seen.add(emergencyId)) {
          continue;
        }
        emergencies.add(await getEmergency(emergencyId));
      }
      return emergencies;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<EmergencyModel>> getPendingEmergencies() async {
    final activeSince = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 30))
        .toIso8601String();
    try {
      final data = await _client
          .from(AppConstants.tableEmergencias)
          .select(_selectWithJoins)
          .eq('estado', AppConstants.statusPending)
          .gte('fecha', activeSince)
          .order('fecha', ascending: false);
      return (data as List)
          .map((e) => EmergencyModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      if (_looksLikeMissingPricingSchema(e)) {
        final data = await _client
            .from(AppConstants.tableEmergencias)
            .select(_selectWithoutPriceSnapshots)
            .eq('estado', AppConstants.statusPending)
            .gte('fecha', activeSince)
            .order('fecha', ascending: false);
        return (data as List)
            .map((e) => EmergencyModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<EmergencyModel>> getPendingEmergenciesForSpecialty(
    String? specialty,
  ) async {
    final emergencies = await getPendingEmergencies();
    final normalized = TechnicianSpecialties.normalizeCode(specialty);
    if (normalized == null || normalized.isEmpty) return emergencies;

    final matching = emergencies.where((emergency) {
      final type = emergency.aiEmergencyType ?? emergency.clasificacionIa;
      return TechnicianSpecialties.matchesEmergencyType(
        specialtyCode: normalized,
        emergencyType: type,
      );
    }).toList();

    return matching.isEmpty ? emergencies : matching;
  }

  bool _looksLikeMissingAiColumns(PostgrestException error) {
    final text = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return text.contains('ai_') && text.contains('column');
  }

  bool _looksLikeMissingPricingSchema(PostgrestException error) {
    final text = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
        .toLowerCase();
    return text.contains('emergency_price_snapshots') ||
        text.contains('service_tariffs') ||
        (text.contains('relationship') && text.contains('schema cache')) ||
        (text.contains('relation') && text.contains('does not exist'));
  }

  int? _tipoProblemaIdForAiType(String? type) {
    return switch (type) {
      'battery' || 'battery_jumpstart' => 3,
      'tire' || 'tire_change' || 'flat_tire_no_spare' => 4,
      'fuel' || 'fuel_delivery' => 5,
      'electrical' => 2,
      'engine' || 'overheating' || 'brakes' || 'minor_mechanic' => 1,
      'tow_service' => 6,
      'accident' ||
      'lockout' ||
      'locksmith_vehicle' ||
      'unknown' ||
      'not_emergency' =>
        6,
      _ => null,
    };
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
      if (_looksLikeMissingPricingSchema(e)) {
        final data = await _client
            .from(AppConstants.tableEmergencias)
            .select(_selectWithoutPriceSnapshots)
            .order('fecha', ascending: false);
        return (data as List)
            .map((e) => EmergencyModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> updateStatus(String id, String estado) async {
    try {
      await _client
          .from(AppConstants.tableEmergencias)
          .update({'estado': estado}).eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> cancelTechnicianService(String emergencyId) async {
    try {
      await _client.rpc(
        'technician_cancel_service',
        params: {'p_emergency_id': emergencyId},
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> assignTechnician(
    String emergencyId,
    String technicianUserId,
  ) async {
    try {
      final technician = await _client
          .from(AppConstants.tableTecnicos)
          .select('id')
          .eq('usuario_id', technicianUserId)
          .eq('estado_verificacion', 'aprobado')
          .single();

      final technicianProfileId = technician['id']?.toString();
      if (technicianProfileId == null || technicianProfileId.isEmpty) {
        throw const ServerException(
          message: 'No se encontro un perfil tecnico aprobado.',
        );
      }

      final active = await getActiveTechnicianEmergency(technicianUserId);
      if (active != null && active.id != emergencyId) {
        throw const ServerException(
          message: 'Ya tienes una emergencia activa. Finalizala antes de aceptar otra.',
        );
      }

      final currentEmergency = await getEmergency(emergencyId);
      if (currentEmergency.estado != AppConstants.statusPending) {
        throw const ServerException(
          message: 'Esta solicitud ya no esta disponible.',
        );
      }

      // Create assignment
      await _client.from(AppConstants.tableAsignaciones).insert({
        'emergencia_id': emergencyId,
        'tecnico_id': technicianProfileId,
        'estado': AppConstants.assignAccepted,
      });

      // Update emergency status
      await _client.from(AppConstants.tableEmergencias).update(
          {'estado': AppConstants.statusInProgress}).eq('id', emergencyId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> createTechnicianOffer(String emergencyId) async {
    try {
      await _client.rpc(
        'create_technician_offer',
        params: {'p_emergency_id': emergencyId},
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> acceptTechnicianOffer(String offerId) async {
    try {
      await _client.rpc(
        'accept_technician_offer',
        params: {'p_offer_id': offerId},
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTechnicianOffers(
    String emergencyId,
  ) async {
    try {
      final data = await _client.rpc(
        'get_technician_offers_for_driver',
        params: {'p_emergency_id': emergencyId},
      );
      return (data as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTechnicianOfferRows(
    String emergencyId,
  ) {
    return _client
        .from(AppConstants.tableTechnicianOffers)
        .stream(primaryKey: ['id']).eq('emergencia_id', emergencyId);
  }

  @override
  Future<bool> hasPendingRating({
    required String userId,
    required String role,
  }) async {
    try {
      final result = await _client.rpc(
        'has_pending_service_rating',
        params: {'p_user_id': userId, 'p_role': role},
      );
      return result == true;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<Map<String, dynamic>?> getPendingRating({
    required String userId,
    required String role,
  }) async {
    try {
      final data = await _client.rpc(
        'get_pending_service_rating',
        params: {'p_user_id': userId, 'p_role': role},
      );
      if (data is! List || data.isEmpty) return null;
      return Map<String, dynamic>.from(data.first as Map);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchEmergency(String id) {
    return _client
        .from(AppConstants.tableEmergencias)
        .stream(primaryKey: ['id']).eq('id', id);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchPendingEmergencies() {
    return _client
        .from(AppConstants.tableEmergencias)
        .stream(primaryKey: ['id']).eq('estado', AppConstants.statusPending);
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
