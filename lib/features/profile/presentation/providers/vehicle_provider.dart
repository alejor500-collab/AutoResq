import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/models/vehicle_model.dart';

const _kVehicleKey = 'autoresq_vehicle';

class VehicleSaveException implements Exception {
  final String message;

  const VehicleSaveException(this.message);

  @override
  String toString() => message;
}

class VehicleNotifier extends StateNotifier<VehicleModel?> {
  final SupabaseClient _supabase;
  final FlutterSecureStorage _storage;
  final String? _userId;

  VehicleNotifier(this._supabase, this._storage, this._userId) : super(null) {
    _load();
  }

  String get _vehicleKey =>
      _userId == null ? _kVehicleKey : '${_kVehicleKey}_$_userId';

  Future<void> _load() async {
    if (_userId != null) {
      try {
        final data = await _supabase
            .from(AppConstants.tableVehiculos)
            .select()
            .eq('usuario_id', _userId)
            .order('id')
            .limit(1);

        if (data.isNotEmpty) {
          final vehicle = VehicleModel.fromJson(data.first);
          await _deleteExtraVehicles(keepId: vehicle.id);
          await _storage.write(
            key: _vehicleKey,
            value: vehicle.toJsonString(),
          );
          state = vehicle;
          return;
        }
      } catch (e) {
        debugPrint('[AutoResQ] vehicle load fallback: $e');
      }
    }

    final raw = await _storage.read(key: _vehicleKey);
    state = VehicleModel.fromJsonString(raw);
  }

  Future<void> _deleteExtraVehicles({String? keepId}) async {
    if (_userId == null || keepId == null) return;
    try {
      final rows = await _supabase
          .from(AppConstants.tableVehiculos)
          .select('id')
          .eq('usuario_id', _userId);
      final extras = List<Map<String, dynamic>>.from(rows)
          .map((row) => row['id'] as String?)
          .where((id) => id != null && id != keepId)
          .cast<String>()
          .toList();

      for (final id in extras) {
        await _supabase
            .from(AppConstants.tableVehiculos)
            .delete()
            .eq('id', id);
      }
    } catch (e) {
      debugPrint('[AutoResQ] vehicle duplicate cleanup skipped: $e');
    }
  }

  Future<void> refresh() => _load();

  Future<void> save(VehicleModel vehicle) async {
    if (_userId == null) {
      throw const VehicleSaveException('Inicia sesión para guardar el vehículo');
    }

    final year = int.tryParse(vehicle.year);
    if (year == null) {
      throw const VehicleSaveException('El año del vehículo no es válido');
    }

    final row = {
      'usuario_id': _userId,
      'marca': vehicle.brand,
      'modelo': vehicle.model,
      'anio': year,
      'placa': vehicle.plate,
      'color': vehicle.color,
    };

    try {
      final existingRows = await _supabase
          .from(AppConstants.tableVehiculos)
          .select('id')
          .eq('usuario_id', _userId)
          .order('id')
          .limit(1);

      final Map<String, dynamic> response;
      if (existingRows.isNotEmpty) {
        final existingId = existingRows.first['id'] as String;
        response = await _supabase
            .from(AppConstants.tableVehiculos)
            .update(row)
            .eq('id', existingId)
            .select()
            .single();
      } else {
        response = await _supabase
            .from(AppConstants.tableVehiculos)
            .insert(row)
            .select()
            .single();
      }

      final saved = VehicleModel.fromJson(response);
      await _deleteExtraVehicles(keepId: saved.id);
      await _storage.write(key: _vehicleKey, value: saved.toJsonString());
      state = saved;
    } on PostgrestException catch (e) {
      debugPrint('[AutoResQ] vehicle save ERROR: ${e.message}');
      final lower = e.message.toLowerCase();
      if (e.code == '23505' || lower.contains('duplicate')) {
        throw const VehicleSaveException(
          'La placa ya está registrada en otra cuenta',
        );
      }
      throw VehicleSaveException(e.message);
    } catch (e) {
      debugPrint('[AutoResQ] vehicle save ERROR: $e');
      if (e is VehicleSaveException) rethrow;
      throw const VehicleSaveException('No se pudo guardar el vehículo');
    }
  }

  Future<void> delete() async {
    final vehicleId = state?.id;
    if (vehicleId != null) {
      await _supabase
          .from(AppConstants.tableVehiculos)
          .delete()
          .eq('id', vehicleId);
    }
    await _storage.delete(key: _vehicleKey);
    state = null;
  }
}

final vehicleProvider =
    StateNotifierProvider<VehicleNotifier, VehicleModel?>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  final userId = ref.watch(authNotifierProvider).value?.id;
  return VehicleNotifier(supabase, const FlutterSecureStorage(), userId);
});
