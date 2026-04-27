import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/vehicle_model.dart';

const _kVehicleKey = 'autoresq_vehicle';

class VehicleNotifier extends StateNotifier<VehicleModel?> {
  final FlutterSecureStorage _storage;

  VehicleNotifier(this._storage) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final raw = await _storage.read(key: _kVehicleKey);
    state = VehicleModel.fromJsonString(raw);
  }

  Future<void> save(VehicleModel vehicle) async {
    await _storage.write(key: _kVehicleKey, value: vehicle.toJsonString());
    state = vehicle;
  }

  Future<void> delete() async {
    await _storage.delete(key: _kVehicleKey);
    state = null;
  }
}

final vehicleProvider =
    StateNotifierProvider<VehicleNotifier, VehicleModel?>((ref) {
  return VehicleNotifier(const FlutterSecureStorage());
});
