import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/datasources/emergency_remote_datasource.dart';
import '../../data/models/emergency_model.dart';
import '../../domain/entities/emergency_entity.dart';

// ─── Data Source ──────────────────────────────────────────────────────────────
final emergencyDataSourceProvider =
    Provider<EmergencyRemoteDataSource>((ref) {
  return EmergencyRemoteDataSourceImpl(
      ref.read(supabaseClientProvider));
});

// ─── DioClient ────────────────────────────────────────────────────────────────
final dioClientProvider = Provider<DioClient>((_) => DioClient());

// ─── Emergency State ──────────────────────────────────────────────────────────
class EmergencyState {
  final List<Emergency> emergencies;
  final Emergency? activeEmergency;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? aiResult;
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
    Map<String, dynamic>? aiResult,
    bool? isAnalyzingAI,
  }) {
    return EmergencyState(
      emergencies: emergencies ?? this.emergencies,
      activeEmergency: activeEmergency ?? this.activeEmergency,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      aiResult: aiResult ?? this.aiResult,
      isAnalyzingAI: isAnalyzingAI ?? this.isAnalyzingAI,
    );
  }
}

// ─── Emergency Notifier ───────────────────────────────────────────────────────
class EmergencyNotifier extends StateNotifier<EmergencyState> {
  final EmergencyRemoteDataSource _dataSource;
  final DioClient _dioClient;
  final Ref _ref;

  EmergencyNotifier(this._dataSource, this._dioClient, this._ref)
      : super(const EmergencyState());

  // ─── AI Analysis ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> analyzeWithAI(String description) async {
    state = state.copyWith(isAnalyzingAI: true, error: null);
    try {
      final result = await _dioClient.analyzeEmergency(description);
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
  }) async {
    final user = _ref.read(authNotifierProvider).value;
    if (user == null) return null;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final created = await _dataSource.createEmergency(
        usuarioId: user.id,
        descripcion: description,
        lat: lat,
        lng: lng,
        direccion: address,
        clasificacionIa: aiAnalysis?.tipo,
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _dataSource.getDriverEmergencies(driverId);
      state = state.copyWith(isLoading: false, emergencies: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Load Pending (Technician) ────────────────────────────────────────────
  Future<void> loadPendingEmergencies() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _dataSource.getPendingEmergencies();
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
    final user = _ref.read(authNotifierProvider).value;
    if (user == null) return false;
    state = state.copyWith(isLoading: true);
    try {
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

  void clearAiResult() {
    state = state.copyWith(aiResult: null);
  }
}

final emergencyNotifierProvider =
    StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
  return EmergencyNotifier(
    ref.read(emergencyDataSourceProvider),
    ref.read(dioClientProvider),
    ref,
  );
});

// ─── Watch Emergency (Realtime) ───────────────────────────────────────────────
final watchEmergencyProvider =
    StreamProvider.family<Emergency, String>((ref, id) {
  final ds = ref.read(emergencyDataSourceProvider);
  return ds.watchEmergency(id).map(
    (rows) {
      if (rows.isEmpty) throw Exception('Emergency not found');
      return EmergencyModel.fromJson(rows.first);
    },
  );
});

// ─── Watch Pending Emergencies (Realtime) ─────────────────────────────────────
final watchPendingProvider =
    StreamProvider<List<Emergency>>((ref) {
  final ds = ref.read(emergencyDataSourceProvider);
  return ds.watchPendingEmergencies().map(
    (rows) => rows
        .map((json) => EmergencyModel.fromJson(json))
        .toList(),
  );
});
