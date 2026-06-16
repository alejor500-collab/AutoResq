import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/emergency_match_policy.dart';
import '../../../../core/constants/technician_specialties.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/emergency_ai_analysis_model.dart';
import '../models/emergency_model.dart';
import '../models/emergency_pricing_model.dart';

class EmergencyPhotoUpload {
  final Uint8List bytes;
  final String fileName;
  final String contentType;

  const EmergencyPhotoUpload({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });
}

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
    String paymentMethod = 'cash',
    List<EmergencyPhotoUpload> evidencePhotos = const [],
    List<String> evidencePhotoUrls = const [],
  });
  Future<List<String>> uploadEmergencyEvidencePhotos({
    required String ownerId,
    required List<EmergencyPhotoUpload> photos,
    String? emergencyId,
  });
  Future<void> createTechnicianOffer(
    String emergencyId, {
    double? offeredAmount,
  });
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
    List<String> evidenceImageUrls = const [],
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
  Future<bool> cancelPendingEmergency(String id);
  Future<void> completeTechnicianService({
    required String emergencyId,
    String? assignmentId,
    String? technicianId,
  });
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
      '*, ubicaciones(*), asignaciones(*, tecnicos(id, usuario_id, especialidad, calificacion_promedio, usuarios!usuario_id(id, nombre, telefono))), usuarios!usuario_id(id, nombre, telefono), emergency_price_snapshots(*), technician_offers(id, tecnico_id, estado, monto_ofertado)';
  static const _selectWithoutPriceSnapshots =
      '*, ubicaciones(*), asignaciones(*, tecnicos(id, usuario_id, especialidad, calificacion_promedio, usuarios!usuario_id(id, nombre, telefono))), usuarios!usuario_id(id, nombre, telefono), technician_offers(id, tecnico_id, estado, monto_ofertado)';

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
    String paymentMethod = 'cash',
    List<EmergencyPhotoUpload> evidencePhotos = const [],
    List<String> evidencePhotoUrls = const [],
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
        'payment_method': paymentMethod,
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
        if (!_looksLikeMissingAiColumns(e) &&
            !_looksLikeMissingPaymentColumns(e)) {
          rethrow;
        }
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

      // 4. Upload evidence photos and attach public URLs to the emergency.
      final existingEvidenceUrls = evidencePhotoUrls
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
      final uploadedEvidenceUrls = <String>[];
      if (existingEvidenceUrls.isEmpty && evidencePhotos.isNotEmpty) {
        try {
          uploadedEvidenceUrls.addAll(
            await uploadEmergencyEvidencePhotos(
              ownerId: usuarioId,
              emergencyId: emergencyData['id']?.toString(),
              photos: evidencePhotos,
            ),
          );
        } catch (_) {
          // La solicitud principal no debe quedar bloqueada por Storage.
        }
      }
      final urls = existingEvidenceUrls.isNotEmpty
          ? existingEvidenceUrls
          : uploadedEvidenceUrls;
      if (urls.isNotEmpty) {
        try {
          await _client
              .from(AppConstants.tableEmergencias)
              .update({'evidence_photo_urls': urls}).eq(
            'id',
            emergencyData['id'],
          );
        } on PostgrestException catch (e) {
          if (!_looksLikeMissingEvidencePhotoColumn(e)) rethrow;
        }
      }

      // 5. Insert historial
      await _client.from(AppConstants.tableHistorial).insert({
        'emergencia_id': emergencyData['id'],
        'actor_id': usuarioId,
        'tipo_evento': 'creacion',
        'descripcion': 'Emergencia creada',
      });

      unawaited(
        _notifyTechniciansAboutEmergency(emergencyData['id']?.toString()),
      );

      // 6. Fetch with joins
      return await getEmergency(emergencyData['id']);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<List<String>> uploadEmergencyEvidencePhotos({
    required String ownerId,
    required List<EmergencyPhotoUpload> photos,
    String? emergencyId,
  }) async {
    if (ownerId.trim().isEmpty || photos.isEmpty) return const [];
    final urls = <String>[];
    final folder = emergencyId?.trim().isNotEmpty == true
        ? emergencyId!.trim()
        : 'pending/$ownerId/${DateTime.now().millisecondsSinceEpoch}';
    for (var index = 0; index < photos.length; index++) {
      final photo = photos[index];
      final ext = _extensionForPhoto(photo.fileName, photo.contentType);
      final path =
          '$folder/${DateTime.now().millisecondsSinceEpoch}_$index.$ext';
      await _client.storage
          .from(AppConstants.bucketEmergencyPhotos)
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: photo.contentType,
            ),
          );
      urls.add(
        _client.storage
            .from(AppConstants.bucketEmergencyPhotos)
            .getPublicUrl(path),
      );
    }
    return urls;
  }

  String _extensionForPhoto(String fileName, String contentType) {
    final lowerName = fileName.toLowerCase();
    final ext = lowerName.contains('.') ? lowerName.split('.').last : '';
    if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      return ext == 'jpeg' ? 'jpg' : ext;
    }
    return switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
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

  Future<void> _notifyDriverAboutAcceptedEmergency(String? emergencyId) async {
    if (emergencyId == null || emergencyId.isEmpty) return;
    try {
      await _client.functions.invoke(
        'notify-emergency-update',
        body: {
          'emergency_id': emergencyId,
          'type': 'solicitud_aceptada',
        },
      );
    } catch (_) {
      // La aceptacion del tecnico no debe fallar si el canal push aun no esta desplegado.
    }
  }

  Future<void> _notifyDriverAboutFinishedEmergency(String? emergencyId) async {
    if (emergencyId == null || emergencyId.isEmpty) return;
    try {
      await _client.functions.invoke(
        'notify-emergency-update',
        body: {
          'emergency_id': emergencyId,
          'type': 'servicio_finalizado',
        },
      );
    } catch (_) {
      // El cierre del servicio no debe fallar si el canal push aun no esta desplegado.
    }
  }

  Future<void> _notifyEmergencyUpdatePush(
    String? emergencyId,
    String type,
  ) async {
    if (emergencyId == null || emergencyId.isEmpty) return;
    try {
      await _client.functions.invoke(
        'notify-emergency-update',
        body: {
          'emergency_id': emergencyId,
          'type': type,
        },
      );
    } catch (_) {
      // La accion principal no debe fallar si el canal push aun no esta desplegado.
    }
  }

  @override
  Future<EmergencyAiAnalysisModel> analyzeEmergency({
    required String description,
    double? lat,
    double? lng,
    String? direccion,
    List<String> evidenceImageUrls = const [],
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
          if (evidenceImageUrls.isNotEmpty)
            'image_urls': evidenceImageUrls.take(2).toList(),
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const ServerException(message: 'Respuesta de IA invalida');
      }

      return EmergencyAiAnalysisModel.fromJson(
        Map<String, dynamic>.from(data),
        fallbackDescription: description,
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
      if (_looksLikeMissingPricingSchema(e)) {
        final data = await _client
            .from(AppConstants.tableEmergencias)
            .select(_selectWithoutPriceSnapshots)
            .eq('estado', AppConstants.statusPending)
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
    final viewerUserId = _client.auth.currentUser?.id;
    final visibleToViewer =
        viewerUserId == null || viewerUserId.isEmpty
            ? emergencies
            : emergencies
                .where((emergency) => emergency.usuarioId != viewerUserId)
                .toList(growable: false);
    final normalized = TechnicianSpecialties.normalizeCode(specialty);
    if (visibleToViewer.isEmpty) return visibleToViewer;

    if (viewerUserId == null || viewerUserId.isEmpty) {
      return _sortPendingEmergenciesByPriority(
        emergencies: visibleToViewer,
        specialty: normalized,
      );
    }

    try {
      final technician = await _client
          .from(AppConstants.tableTecnicos)
          .select('id, ubicacion_lat, ubicacion_lng, calificacion_promedio')
          .eq('usuario_id', viewerUserId)
          .maybeSingle();
      final technicianId = technician?['id']?.toString();
      if (technicianId == null || technicianId.isEmpty) {
        return _sortPendingEmergenciesByPriority(
          emergencies: visibleToViewer,
          specialty: normalized,
        );
      }

      final prioritized = await _rankPendingEmergenciesForTechnician(
        emergencies: visibleToViewer,
        currentTechnicianId: technicianId,
        currentTechnicianLat: (technician?['ubicacion_lat'] as num?)?.toDouble(),
        currentTechnicianLng: (technician?['ubicacion_lng'] as num?)?.toDouble(),
        currentTechnicianRating:
            (technician?['calificacion_promedio'] as num?)?.toDouble() ?? 0,
        specialty: normalized,
      );

      final rows = await _client
          .from(AppConstants.tableTechnicianOffers)
          .select('emergencia_id, monto_ofertado, estado')
          .eq('tecnico_id', technicianId)
          .inFilter(
            'emergencia_id',
            prioritized.map((emergency) => emergency.id).toList(),
          );

      final offersByEmergencyId = <String, Map<String, dynamic>>{};
      for (final row in rows as List) {
        final data = Map<String, dynamic>.from(row as Map);
        final emergencyId = data['emergencia_id']?.toString();
        if (emergencyId == null || emergencyId.isEmpty) continue;
        offersByEmergencyId[emergencyId] = data;
      }

      return prioritized.map((emergency) {
        final offer = offersByEmergencyId[emergency.id];
        if (offer == null) return emergency;
        return emergency.copyWith(
          myOfferStatus: offer['estado']?.toString(),
          myOfferedAmount: (offer['monto_ofertado'] as num?)?.toDouble(),
        );
      }).toList();
    } on PostgrestException {
      return _sortPendingEmergenciesByPriority(
        emergencies: visibleToViewer,
        specialty: normalized,
      );
    }
  }

  Future<List<EmergencyModel>> _sortPendingEmergenciesByPriority({
    required List<EmergencyModel> emergencies,
    String? specialty,
  }) async {
    if (emergencies.length <= 1) return emergencies;

    final normalizedSpecialty = TechnicianSpecialties.normalizeCode(specialty);
    if (normalizedSpecialty == null || normalizedSpecialty.isEmpty) {
      final sorted = [...emergencies];
      sorted.sort((a, b) => b.fecha.compareTo(a.fecha));
      return sorted;
    }

    final sorted = [...emergencies];
    sorted.sort((a, b) {
      final aMatch = TechnicianSpecialties.matchesEmergencyType(
        specialtyCode: normalizedSpecialty,
        emergencyType: a.aiEmergencyType ?? a.clasificacionIa,
      );
      final bMatch = TechnicianSpecialties.matchesEmergencyType(
        specialtyCode: normalizedSpecialty,
        emergencyType: b.aiEmergencyType ?? b.clasificacionIa,
      );
      if (aMatch != bMatch) return aMatch ? -1 : 1;
      return b.fecha.compareTo(a.fecha);
    });
    return sorted;
  }

  Future<List<EmergencyModel>> _rankPendingEmergenciesForTechnician({
    required List<EmergencyModel> emergencies,
    required String currentTechnicianId,
    required double? currentTechnicianLat,
    required double? currentTechnicianLng,
    required double currentTechnicianRating,
    required String? specialty,
  }) async {
    if (emergencies.isEmpty) return emergencies;

    final technicians = await _loadAvailableTechnicianLocations();
    final currentFromRoster = technicians[currentTechnicianId];
    final current = currentFromRoster ??
        _TechnicianMatchLocation(
          id: currentTechnicianId,
          userId: null,
          specialty: null,
          lat: currentTechnicianLat,
          lng: currentTechnicianLng,
          rating: currentTechnicianRating,
        );

    final currentHasLocation = current.lat != null && current.lng != null;
    if (!currentHasLocation) {
      return _sortPendingEmergenciesByPriority(
        emergencies: emergencies,
        specialty: specialty,
      );
    }

    final ranked = <({EmergencyModel emergency, int priorityRank, bool specialtyMatch})>[];
    for (final emergency in emergencies) {
      final emergencyType = emergency.aiEmergencyType ?? emergency.clasificacionIa;
      final specialtyMatch = TechnicianSpecialties.matchesEmergencyType(
        specialtyCode: specialty,
        emergencyType: emergencyType,
      );
      final compatibleTechnicians = technicians.values.where((technician) {
        if (technician.userId == emergency.usuarioId) return false;
        return TechnicianSpecialties.matchesEmergencyType(
          specialtyCode: technician.specialty,
          emergencyType: emergencyType,
        );
      });

      final rankedTechnicians = EmergencyMatchPolicy.visibleRanked<_TechnicianMatchLocation>(
        items: compatibleTechnicians,
        emergencyType: emergencyType,
        distanceKm: (technician) => _distanceKm(
          emergency.lat,
          emergency.lng,
          technician.lat,
          technician.lng,
        ),
        rating: (technician) => technician.rating,
      );

      final hasCurrentTechnician = rankedTechnicians.any(
        (technician) => technician.id == currentTechnicianId,
      );
      var priorityRank = 9;
      if (hasCurrentTechnician) {
        priorityRank = 0;
      } else {
        final currentDistance = _distanceKm(
          emergency.lat,
          emergency.lng,
          current.lat,
          current.lng,
        );
        if (currentDistance == null) {
          priorityRank = 1;
        } else {
          final currentBand = EmergencyMatchPolicy.bandFor(
            emergencyType: emergencyType,
            distanceKm: currentDistance,
          );
          final hasNearbyOptions = rankedTechnicians.any((technician) {
            final band = EmergencyMatchPolicy.bandFor(
              emergencyType: emergencyType,
              distanceKm: _distanceKm(
                emergency.lat,
                emergency.lng,
                technician.lat,
                technician.lng,
              ),
            );
            return band?.isNearby == true;
          });
          if (currentBand != null) {
            priorityRank = currentBand.isNearby || !hasNearbyOptions
                ? currentBand.rank + 1
                : currentBand.rank + 4;
          } else {
            priorityRank = hasNearbyOptions ? 8 : 3;
          }
        }
      }

      ranked.add((
        emergency: emergency,
        priorityRank: priorityRank,
        specialtyMatch: specialtyMatch,
      ));
    }

    ranked.sort((a, b) {
      if (a.specialtyMatch != b.specialtyMatch) {
        return a.specialtyMatch ? -1 : 1;
      }
      final rankCompare = a.priorityRank.compareTo(b.priorityRank);
      if (rankCompare != 0) return rankCompare;
      final aDistance = _distanceKm(
        a.emergency.lat,
        a.emergency.lng,
        current.lat,
        current.lng,
      );
      final bDistance = _distanceKm(
        b.emergency.lat,
        b.emergency.lng,
        current.lat,
        current.lng,
      );
      final distanceCompare =
          (aDistance ?? double.infinity).compareTo(bDistance ?? double.infinity);
      if (distanceCompare != 0) return distanceCompare;
      return b.emergency.fecha.compareTo(a.emergency.fecha);
    });

    return ranked.map((entry) => entry.emergency).toList();
  }

  Future<Map<String, _TechnicianMatchLocation>>
      _loadAvailableTechnicianLocations() async {
    final rows = await _client
        .from(AppConstants.tableTecnicos)
        .select(
          'id, usuario_id, especialidad, ubicacion_lat, ubicacion_lng, calificacion_promedio',
        )
        .eq('estado_verificacion', 'aprobado')
        .eq('disponible', true);

    final technicians = <String, _TechnicianMatchLocation>{};
    for (final row in rows as List) {
      final data = Map<String, dynamic>.from(row as Map);
      final id = data['id']?.toString();
      if (id == null || id.isEmpty) continue;
      technicians[id] = _TechnicianMatchLocation(
        id: id,
        userId: data['usuario_id']?.toString(),
        specialty: data['especialidad']?.toString(),
        lat: (data['ubicacion_lat'] as num?)?.toDouble(),
        lng: (data['ubicacion_lng'] as num?)?.toDouble(),
        rating: (data['calificacion_promedio'] as num?)?.toDouble() ?? 0,
      );
    }

    try {
      final locations = await _client
          .from('ubicaciones_tecnico')
          .select('tecnico_id, latitud, longitud');
      for (final row in locations as List) {
        final data = Map<String, dynamic>.from(row as Map);
        final id = data['tecnico_id']?.toString();
        final current = id == null ? null : technicians[id];
        if (id == null || current == null) continue;
        technicians[id] = current.copyWith(
          lat: (data['latitud'] as num?)?.toDouble() ?? current.lat,
          lng: (data['longitud'] as num?)?.toDouble() ?? current.lng,
        );
      }
    } on PostgrestException {
      // Stored technician coordinates are enough when live location rows are hidden.
    }

    return technicians;
  }

  double? _distanceKm(
    double? latA,
    double? lngA,
    double? latB,
    double? lngB,
  ) {
    if (latA == null || lngA == null || latB == null || lngB == null) {
      return null;
    }

    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(latB - latA);
    final dLng = _toRadians(lngB - lngA);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(latA)) *
            math.cos(_toRadians(latB)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

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

  bool _looksLikeMissingPaymentColumns(PostgrestException error) {
    final text = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return text.contains('payment_method') && text.contains('column');
  }

  bool _looksLikeMissingEvidencePhotoColumn(PostgrestException error) {
    final text =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return text.contains('evidence_photo_urls') && text.contains('column');
  }

  int? _tipoProblemaIdForAiType(String? type) {
    return switch (type) {
      'Sistema eléctrico y batería' => 3,
      'Llantas y vulcanización' => 4,
      'Combustible' => 5,
      'Mecánica rápida' => 1,
      'Grúa / remolque' => 6,
      'Cerrajería vehicular' || 'Auxilio general' => 6,
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

  void _assertNotOwnEmergency(EmergencyModel emergency, String userId) {
    if (emergency.usuarioId == userId) {
      throw const ServerException(
        message: 'No puedes responder tu propia solicitud de emergencia.',
      );
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
  Future<bool> cancelPendingEmergency(String id) async {
    try {
      final updated = await _client
          .from(AppConstants.tableEmergencias)
          .update({'estado': AppConstants.statusCancelled})
          .eq('id', id)
          .eq('estado', AppConstants.statusPending)
          .select('id')
          .maybeSingle();
      final cancelled = updated != null;
      if (cancelled) {
        unawaited(_notifyEmergencyUpdatePush(id, 'solicitud_cancelada'));
      }
      return cancelled;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> completeTechnicianService({
    required String emergencyId,
    String? assignmentId,
    String? technicianId,
  }) async {
    try {
      final cleanAssignmentId = assignmentId?.trim();
      if (cleanAssignmentId != null && cleanAssignmentId.isNotEmpty) {
        await _client
            .from(AppConstants.tableAsignaciones)
            .update({'estado': AppConstants.assignFinished}).eq(
          'id',
          cleanAssignmentId,
        );
      } else {
        await _client
            .from(AppConstants.tableAsignaciones)
            .update({'estado': AppConstants.assignFinished})
            .eq('emergencia_id', emergencyId)
            .inFilter('estado', [
          AppConstants.assignAccepted,
          AppConstants.assignEnRoute,
          AppConstants.assignAttending,
        ]);
      }

      await _client
          .from(AppConstants.tableEmergencias)
          .update({'estado': AppConstants.statusCompleted}).eq(
        'id',
        emergencyId,
      );

      final cleanTechnicianId = technicianId?.trim();
      if (cleanTechnicianId != null && cleanTechnicianId.isNotEmpty) {
        await _client
            .from(AppConstants.tableTecnicos)
            .update({'disponible': true}).eq('id', cleanTechnicianId);
      } else {
        final currentUserId = _client.auth.currentUser?.id;
        if (currentUserId != null && currentUserId.isNotEmpty) {
          await _client
              .from(AppConstants.tableTecnicos)
              .update({'disponible': true}).eq('usuario_id', currentUserId);
        }
      }

      unawaited(_notifyDriverAboutFinishedEmergency(emergencyId));
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
      unawaited(_notifyEmergencyUpdatePush(emergencyId, 'tecnico_cancelo'));
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
      _assertNotOwnEmergency(currentEmergency, technicianUserId);
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

      unawaited(_notifyDriverAboutAcceptedEmergency(emergencyId));
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<void> createTechnicianOffer(
    String emergencyId, {
    double? offeredAmount,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final currentEmergency = await getEmergency(emergencyId);
        _assertNotOwnEmergency(currentEmergency, currentUserId);
      }
      await _client.rpc(
        'create_technician_offer',
        params: {
          'p_emergency_id': emergencyId,
          'p_offered_amount': offeredAmount,
        },
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

class _TechnicianMatchLocation {
  final String id;
  final String? userId;
  final String? specialty;
  final double? lat;
  final double? lng;
  final double rating;

  const _TechnicianMatchLocation({
    required this.id,
    required this.userId,
    required this.specialty,
    required this.lat,
    required this.lng,
    required this.rating,
  });

  _TechnicianMatchLocation copyWith({
    double? lat,
    double? lng,
  }) {
    return _TechnicianMatchLocation(
      id: id,
      userId: userId,
      specialty: specialty,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      rating: rating,
    );
  }
}
