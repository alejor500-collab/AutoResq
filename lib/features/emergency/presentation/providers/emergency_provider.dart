import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/datasources/emergency_remote_datasource.dart';
import '../../data/models/emergency_ai_analysis_model.dart';
import '../../data/models/emergency_model.dart';
import '../../data/models/emergency_pricing_model.dart';
import '../../data/services/emergency_pricing_service.dart';
import '../../domain/entities/emergency_entity.dart';

// ─── Data Source ──────────────────────────────────────────────────────────────
final emergencyDataSourceProvider = Provider<EmergencyRemoteDataSource>((ref) {
  return EmergencyRemoteDataSourceImpl(ref.read(supabaseClientProvider));
});

final emergencyPricingServiceProvider = Provider<EmergencyPricingService>((ref) {
  return EmergencyPricingService(ref.read(supabaseClientProvider));
});

// ─── DioClient ────────────────────────────────────────────────────────────────
// ─── Emergency State ──────────────────────────────────────────────────────────
class EmergencyState {
  final List<Emergency> emergencies;
  final Emergency? activeEmergency;
  final bool isLoading;
  final String? error;
  final EmergencyAiAnalysisModel? aiResult;
  final bool isAnalyzingAI;

  const EmergencyState({
    this.emergencies = const [],
    this.activeEmergency,
    this.isLoading = false,
    this.error,
    this.aiResult,
    this.isAnalyzingAI = false,
  });

  EmergencyState copyWith({
    List<Emergency>? emergencies,
    Emergency? activeEmergency,
    bool? isLoading,
    String? error,
    EmergencyAiAnalysisModel? aiResult,
    bool? isAnalyzingAI,
    bool clearActiveEmergency = false,
  }) {
    return EmergencyState(
      emergencies: emergencies ?? this.emergencies,
      activeEmergency:
          clearActiveEmergency ? null : activeEmergency ?? this.activeEmergency,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      aiResult: aiResult ?? this.aiResult,
      isAnalyzingAI: isAnalyzingAI ?? this.isAnalyzingAI,
    );
  }
}

class TechnicianOffer {
  final String id;
  final String emergencyId;
  final String technicianId;
  final String technicianUserId;
  final String name;
  final String? phone;
  final String? specialty;
  final double rating;
  final int totalServices;
  final double? distanceKm;
  final int? etaMinutes;
  final double? offeredAmount;
  final String status;
  final DateTime createdAt;

  const TechnicianOffer({
    required this.id,
    required this.emergencyId,
    required this.technicianId,
    required this.technicianUserId,
    required this.name,
    this.phone,
    this.specialty,
    required this.rating,
    required this.totalServices,
    this.distanceKm,
    this.etaMinutes,
    this.offeredAmount,
    required this.status,
    required this.createdAt,
  });

  factory TechnicianOffer.fromJson(Map<String, dynamic> json) {
    final technician = json['tecnicos'] is Map
        ? Map<String, dynamic>.from(json['tecnicos'] as Map)
        : const <String, dynamic>{};
    final technicianUser = technician['usuarios'] is Map
        ? Map<String, dynamic>.from(technician['usuarios'] as Map)
        : const <String, dynamic>{};

    return TechnicianOffer(
      id: json['id']?.toString() ?? '',
      emergencyId: json['emergencia_id']?.toString() ?? '',
      technicianId:
          json['tecnico_id']?.toString() ?? json['technician_id']?.toString() ?? '',
      technicianUserId: technician['usuario_id']?.toString() ??
          json['technician_user_id']?.toString() ??
          '',
      name: (json['technician_name'] ?? technicianUser['nombre'])
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true
          ? (json['technician_name'] ?? technicianUser['nombre']).toString()
          : technicianUser['nombre']?.toString().trim().isNotEmpty == true
          ? technicianUser['nombre'].toString()
          : 'Tecnico verificado',
      phone: json['technician_phone']?.toString() ??
          technicianUser['telefono']?.toString(),
      specialty:
          json['specialty']?.toString() ?? technician['especialidad']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ??
          (technician['calificacion_promedio'] as num?)?.toDouble() ??
          0,
      totalServices: (json['total_services'] as num?)?.toInt() ??
          (technician['total_servicios'] as num?)?.toInt() ??
          0,
      distanceKm: (json['distancia_km'] as num?)?.toDouble(),
      etaMinutes: (json['eta_minutos'] as num?)?.toInt(),
      offeredAmount: (json['monto_ofertado'] as num?)?.toDouble(),
      status: json['estado']?.toString() ?? 'pendiente',
      createdAt: DateTime.tryParse(json['fecha_oferta']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get ratingLabel => rating <= 0 ? 'Nuevo' : rating.toStringAsFixed(1);

  String get distanceLabel {
    final value = distanceKm;
    if (value == null) return 'Cerca de ti';
    if (value < 1) return '${(value * 1000).round()} m';
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} km';
  }

  String get etaLabel {
    final value = etaMinutes;
    if (value == null) return 'ETA por confirmar';
    return '$value min';
  }
}

// ─── Emergency Notifier ───────────────────────────────────────────────────────
class EmergencyNotifier extends StateNotifier<EmergencyState> {
  final EmergencyRemoteDataSource _dataSource;
  final Ref _ref;

  EmergencyNotifier(this._dataSource, this._ref)
      : super(const EmergencyState());

  AppUser? get _currentUser =>
      _ref.read(authNotifierProvider).value ??
      _ref.read(authStateProvider).valueOrNull;

  // ─── AI Analysis ─────────────────────────────────────────────────────────
  Future<EmergencyAiAnalysisModel?> analyzeWithAI(
    String description, {
    double? lat,
    double? lng,
    String? address,
  }) async {
    state = state.copyWith(isAnalyzingAI: true, error: null);
    try {
      final result = await _dataSource.analyzeEmergency(
        description: description,
        lat: lat,
        lng: lng,
        direccion: address,
      );
      state = state.copyWith(isAnalyzingAI: false, aiResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(
        isAnalyzingAI: false,
        error: 'No se pudo analizar con IA.',
      );
      return null;
    }
  }

  // ─── Create Emergency ─────────────────────────────────────────────────────
  Future<Emergency?> createEmergency({
    required String description,
    required double lat,
    required double lng,
    String? address,
    AiAnalysis? aiAnalysis,
    bool skipAiAnalysis = false,
    EmergencyPriceQuote? priceQuote,
  }) async {
    final user = _currentUser;
    if (user == null) return null;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final active = await _dataSource.getActiveDriverEmergency(user.id);
      if (active != null) {
        state = state.copyWith(
          isLoading: false,
          activeEmergency: active,
          error: 'Ya tienes una emergencia activa.',
        );
        return null;
      }

      final hasPendingRating = await _dataSource.hasPendingRating(
        userId: user.id,
        role: 'driver',
      );
      if (hasPendingRating) {
        state = state.copyWith(
          isLoading: false,
          error: 'Tienes una calificacion pendiente.',
        );
        return null;
      }

      EmergencyAiAnalysisModel? analysisModel;
      var analysisStatus = 'pending';
      if (aiAnalysis != null) {
        analysisModel = EmergencyAiAnalysisModel(
          isValidEmergency: aiAnalysis.isValidEmergency,
          emergencyType: aiAnalysis.emergencyType,
          priority: aiAnalysis.priority,
          userMessage: aiAnalysis.userMessage,
          safetyRecommendation: aiAnalysis.safetyRecommendation,
          technicianSummary: aiAnalysis.technicianSummary,
          detectedRisks: aiAnalysis.detectedRisks,
          requiresImmediateAttention: aiAnalysis.requiresImmediateAttention,
          confidence: aiAnalysis.confidence,
        );
        analysisStatus = 'completed';
      } else if (skipAiAnalysis) {
        analysisStatus = 'failed';
      } else {
        try {
          analysisModel = await _dataSource.analyzeEmergency(
            description: description,
            lat: lat,
            lng: lng,
            direccion: address,
          );
          analysisStatus = 'completed';
        } catch (_) {
          analysisStatus = 'failed';
        }
      }

      final created = await _dataSource.createEmergency(
        usuarioId: user.id,
        descripcion: description,
        lat: lat,
        lng: lng,
        direccion: address,
        aiAnalysis: analysisModel,
        aiAnalysisStatus: analysisStatus,
        priceQuote: priceQuote,
      );
      state = state.copyWith(
        isLoading: false,
        activeEmergency: created,
      );
      return created;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // ─── Load Driver History ──────────────────────────────────────────────────
  Future<void> loadDriverEmergencies(String driverId) async {
    state = state.copyWith(isLoading: true, error: null, emergencies: []);
    try {
      final list = await _dataSource.getDriverEmergencies(driverId);
      state = state.copyWith(isLoading: false, emergencies: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Emergency?> loadActiveDriverEmergency() async {
    final user = _currentUser;
    if (user == null) return null;
    try {
      final active = await _dataSource.getActiveDriverEmergency(user.id);
      state = state.copyWith(
        activeEmergency: active,
        clearActiveEmergency: active == null,
      );
      return active;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<Emergency?> loadActiveTechnicianEmergency() async {
    final user = _currentUser;
    if (user == null) return null;
    try {
      final active = await _dataSource.getActiveTechnicianEmergency(user.id);
      state = state.copyWith(
        activeEmergency: active,
        clearActiveEmergency: active == null,
      );
      return active;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  // ─── Load Pending (Technician) ────────────────────────────────────────────
  Future<void> loadPendingEmergencies() async {
    state = state.copyWith(isLoading: true, error: null, emergencies: []);
    try {
      final user = _currentUser;
      final list = await _dataSource.getPendingEmergenciesForSpecialty(
        user?.specialty,
      );
      state = state.copyWith(isLoading: false, emergencies: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Load All (Admin) ─────────────────────────────────────────────────────
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _dataSource.getAllEmergencies();
      state = state.copyWith(isLoading: false, emergencies: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Accept Emergency (Technician) ────────────────────────────────────────
  Future<bool> acceptEmergency(String emergencyId) async {
    final user = _currentUser;
    if (user == null) return false;
    state = state.copyWith(isLoading: true);
    try {
      final hasPendingRating = await _dataSource.hasPendingRating(
        userId: user.id,
        role: 'technician',
      );
      if (hasPendingRating) {
        state = state.copyWith(
          isLoading: false,
          error: 'Tienes una calificacion pendiente.',
        );
        return false;
      }
      final active = await _dataSource.getActiveTechnicianEmergency(user.id);
      if (active != null && active.id != emergencyId) {
        state = state.copyWith(
          isLoading: false,
          activeEmergency: active,
          error: 'Ya tienes una emergencia activa.',
        );
        return false;
      }
      await _dataSource.assignTechnician(emergencyId, user.id);
      // Refetch with joins
      final updated = await _dataSource.getEmergency(emergencyId);
      state = state.copyWith(isLoading: false, activeEmergency: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> createTechnicianOffer(String emergencyId) async {
    final user = _currentUser;
    if (user == null) return false;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final hasPendingRating = await _dataSource.hasPendingRating(
        userId: user.id,
        role: 'technician',
      );
      if (hasPendingRating) {
        state = state.copyWith(
          isLoading: false,
          error: 'Tienes una calificacion pendiente.',
        );
        return false;
      }
      final active = await _dataSource.getActiveTechnicianEmergency(user.id);
      if (active != null && active.id != emergencyId) {
        state = state.copyWith(
          isLoading: false,
          activeEmergency: active,
          error: 'Ya tienes una emergencia activa.',
        );
        return false;
      }
      await _dataSource.createTechnicianOffer(emergencyId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> acceptTechnicianOffer(String offerId, String emergencyId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dataSource.acceptTechnicianOffer(offerId);
      final updated = await _dataSource.getEmergency(emergencyId);
      state = state.copyWith(isLoading: false, activeEmergency: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ─── Update Status ────────────────────────────────────────────────────────
  Future<bool> updateStatus(String emergencyId, String status) async {
    state = state.copyWith(isLoading: true);
    try {
      await _dataSource.updateStatus(emergencyId, status);
      final updated = await _dataSource.getEmergency(emergencyId);
      state = state.copyWith(isLoading: false, activeEmergency: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void setActiveEmergency(Emergency emergency) {
    state = state.copyWith(activeEmergency: emergency);
  }

  void clearActiveEmergency() {
    state = state.copyWith(clearActiveEmergency: true);
  }

  void clearAiResult() {
    state = state.copyWith(aiResult: null);
  }

  Future<Map<String, dynamic>?> getPendingRating(String role) async {
    final user = _currentUser;
    if (user == null) return null;
    return _dataSource.getPendingRating(userId: user.id, role: role);
  }

  Future<bool> hasPendingRating(String role) async {
    final user = _currentUser;
    if (user == null) return false;
    return _dataSource.hasPendingRating(userId: user.id, role: role);
  }

}

final emergencyNotifierProvider =
    StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
  return EmergencyNotifier(
    ref.read(emergencyDataSourceProvider),
    ref,
  );
});

// ─── Watch Emergency (Realtime) ───────────────────────────────────────────────
final watchEmergencyProvider =
    StreamProvider.family<Emergency, String>((ref, id) {
  final ds = ref.read(emergencyDataSourceProvider);
  return (() async* {
    yield await ds.getEmergency(id);
    yield* Stream.periodic(const Duration(seconds: 2)).asyncMap(
      (_) => ds.getEmergency(id),
    );
  })();
});

final technicianOffersProvider =
    StreamProvider.family<List<TechnicianOffer>, String>((ref, emergencyId) {
  final ds = ref.read(emergencyDataSourceProvider);
  return (() async* {
    yield (await ds.getTechnicianOffers(emergencyId))
        .map(TechnicianOffer.fromJson)
        .toList();
    yield* ds.watchTechnicianOfferRows(emergencyId).asyncMap((_) async {
      return (await ds.getTechnicianOffers(emergencyId))
          .map(TechnicianOffer.fromJson)
          .toList();
    });
  })();
});

// ─── Watch Pending Emergencies (Realtime) ─────────────────────────────────────
final watchPendingProvider = StreamProvider<List<Emergency>>((ref) {
  final ds = ref.read(emergencyDataSourceProvider);
  return ds.watchPendingEmergencies().map(
        (rows) => rows.map((json) => EmergencyModel.fromJson(json)).toList(),
      );
});

final technicianPendingEmergenciesProvider =
    StreamProvider.autoDispose<List<Emergency>>((ref) async* {
  final user = ref.watch(authNotifierProvider).value ??
      ref.watch(authStateProvider).valueOrNull;
  if (user == null || !user.isApproved) {
    yield const [];
    return;
  }

  final ds = ref.read(emergencyDataSourceProvider);
  Future<List<Emergency>> fetchPending() {
    return ds.getPendingEmergenciesForSpecialty(user.specialty);
  }

  yield await fetchPending();
  yield* Stream.periodic(const Duration(seconds: 4)).asyncMap(
    (_) => fetchPending(),
  );
});

final activeTechnicianEmergencyProvider =
    StreamProvider.autoDispose<Emergency?>((ref) async* {
  final user = ref.watch(authNotifierProvider).value ??
      ref.watch(authStateProvider).valueOrNull;
  if (user == null || !user.isApproved) {
    yield null;
    return;
  }

  final ds = ref.read(emergencyDataSourceProvider);
  Future<Emergency?> fetchActive() {
    return ds.getActiveTechnicianEmergency(user.id);
  }

  yield await fetchActive();
  yield* Stream.periodic(const Duration(seconds: 3)).asyncMap(
    (_) => fetchActive(),
  );
});

final technicianEmergencyHistoryProvider =
    FutureProvider<List<Emergency>>((ref) async {
  final user = ref.watch(authNotifierProvider).value ??
      ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const [];
  return ref.read(emergencyDataSourceProvider).getTechnicianEmergencies(user.id);
});

final driverEmergencyHistoryProvider =
    FutureProvider<List<Emergency>>((ref) async {
  final user = ref.watch(authNotifierProvider).value ??
      ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const [];
  return ref.read(emergencyDataSourceProvider).getDriverEmergencies(user.id);
});

class TechnicianLiveLocation {
  final double lat;
  final double lng;
  final DateTime updatedAt;

  const TechnicianLiveLocation({
    required this.lat,
    required this.lng,
    required this.updatedAt,
  });

  factory TechnicianLiveLocation.fromJson(Map<String, dynamic> json) {
    return TechnicianLiveLocation(
      lat: (json['latitud'] as num).toDouble(),
      lng: (json['longitud'] as num).toDouble(),
      updatedAt: DateTime.parse(json['actualizado_en'] as String),
    );
  }
}

final technicianLiveLocationProvider =
    StreamProvider.family<TechnicianLiveLocation?, String>((ref, technicianId) {
  if (technicianId.isEmpty) {
    return Stream<TechnicianLiveLocation?>.value(null);
  }
  final client = ref.read(supabaseClientProvider);
  Future<TechnicianLiveLocation?> fetch() async {
    final row = await client
        .from(AppConstants.tableUbicacionesTecnico)
        .select('latitud, longitud, actualizado_en')
        .eq('tecnico_id', technicianId)
        .maybeSingle();
    if (row == null) return null;
    return TechnicianLiveLocation.fromJson(row);
  }

  return (() async* {
    yield await fetch();
    yield* Stream.periodic(const Duration(seconds: 2)).asyncMap(
      (_) => fetch(),
    );
  })();
});

final updateTechnicianLiveLocationProvider = FutureProvider.family
    .autoDispose<void, ({String technicianId, double lat, double lng})>(
        (ref, args) async {
  final client = ref.read(supabaseClientProvider);
  await client.from(AppConstants.tableUbicacionesTecnico).upsert({
    'tecnico_id': args.technicianId,
    'latitud': args.lat,
    'longitud': args.lng,
    'actualizado_en': DateTime.now().toUtc().toIso8601String(),
  }, onConflict: 'tecnico_id');
});

class RouteEstimate {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final String source;
  final bool isApproximate;

  const RouteEstimate({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.source,
    required this.isApproximate,
  });

  String get distanceLabel {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(distanceKm >= 10 ? 0 : 1)} km';
  }
}

typedef RouteEstimateArgs = ({
  double originLat,
  double originLng,
  double destinationLat,
  double destinationLng,
});

final technicianRouteEstimateProvider =
    FutureProvider.family<RouteEstimate, RouteEstimateArgs>((ref, args) async {
  final origin = LatLng(args.originLat, args.originLng);
  final destination = LatLng(args.destinationLat, args.destinationLng);
  try {
    final response = await Dio().get<Map<String, dynamic>>(
      'https://router.project-osrm.org/route/v1/driving/'
      '${args.originLng},${args.originLat};'
      '${args.destinationLng},${args.destinationLat}',
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      ),
    );

    final routes = response.data?['routes'];
    if (routes is List && routes.isNotEmpty) {
      final route = Map<String, dynamic>.from(routes.first as Map);
      final geometry = route['geometry'];
      final coordinates = geometry is Map ? geometry['coordinates'] : null;
      final points = coordinates is List
          ? coordinates
              .whereType<List>()
              .where((point) => point.length >= 2)
              .map(
                (point) => LatLng(
                  (point[1] as num).toDouble(),
                  (point[0] as num).toDouble(),
                ),
              )
              .toList()
          : <LatLng>[];
      final distanceKm = ((route['distance'] as num?)?.toDouble() ?? 0) / 1000;
      final durationMinutes =
          math.max(1, (((route['duration'] as num?)?.toDouble() ?? 0) / 60).round());
      if (points.length >= 2 && distanceKm > 0) {
        return RouteEstimate(
          points: points,
          distanceKm: distanceKm,
          durationMinutes: durationMinutes,
          source: 'route_api',
          isApproximate: false,
        );
      }
    }
  } catch (_) {
    // Fallback below keeps the driver informed when the route API is unavailable.
  }

  final distanceKm = const Distance().as(
    LengthUnit.Kilometer,
    origin,
    destination,
  );
  final durationMinutes = math.max(1, (distanceKm / 25 * 60).round());
  return RouteEstimate(
    points: [origin, destination],
    distanceKm: distanceKm,
    durationMinutes: durationMinutes,
    source: 'haversine',
    isApproximate: true,
  );
});
