import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/location_entity.dart';

class MapState {
  final LocationEntity? currentLocation;
  final bool isLoading;
  final String? error;
  final double zoom;

  const MapState({
    this.currentLocation,
    this.isLoading = false,
    this.error,
    this.zoom = AppConstants.defaultZoom,
  });

  MapState copyWith({
    LocationEntity? currentLocation,
    bool? isLoading,
    String? error,
    double? zoom,
  }) {
    return MapState(
      currentLocation: currentLocation ?? this.currentLocation,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      zoom: zoom ?? this.zoom,
    );
  }
}

class MapNotifier extends StateNotifier<MapState> {
  final DioClient _dioClient;

  MapNotifier(this._dioClient) : super(const MapState());

  Future<void> getCurrentLocation() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoading: false,
          error: 'El servicio de ubicación está desactivado',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLoading: false,
            error: 'Permiso de ubicación denegado',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          error: 'Permiso de ubicación denegado permanentemente',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final address = await _dioClient.reverseGeocode(
          position.latitude, position.longitude);

      state = state.copyWith(
        isLoading: false,
        currentLocation: LocationEntity(
          lat: position.latitude,
          lng: position.longitude,
          address: address,
        ),
      );
    } catch (e) {
      // Fallback to Riobamba center
      state = state.copyWith(
        isLoading: false,
        currentLocation: const LocationEntity(
          lat: AppConstants.defaultLat,
          lng: AppConstants.defaultLng,
          address: 'Riobamba, Chimborazo, Ecuador',
        ),
      );
    }
  }

  void setZoom(double zoom) => state = state.copyWith(zoom: zoom);
}

final mapNotifierProvider =
    StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier(DioClient());
});
