import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class DioClient {
  static DioClient? _instance;
  late final Dio _dio;

  DioClient._() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.next(options),
        onResponse: (response, handler) => handler.next(response),
        onError: (error, handler) => handler.next(error),
      ),
    );
  }

  factory DioClient() {
    _instance ??= DioClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  static String formatCoordinates(double lat, double lng) {
    return 'Lat ${lat.toStringAsFixed(5)}, Lng ${lng.toStringAsFixed(5)}';
  }

  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        '${AppConstants.nominatimUrl}/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'jsonv2',
          'accept-language': 'es',
          'addressdetails': 1,
          'zoom': 18,
          'email': 'autoresq@espoch.edu.ec',
        },
        options: Options(
          headers: {
            'User-Agent': 'AutoResQ/1.0 (autoresq@espoch.edu.ec)',
          },
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return formatCoordinates(lat, lng);
      }
      final displayName = (data['display_name'] as String?)?.trim();
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }
      final address = _formatAddressFromParts(data['address']);
      if (address != null) {
        return address;
      }
      return formatCoordinates(lat, lng);
    } catch (_) {
      return formatCoordinates(lat, lng);
    }
  }

  String? _formatAddressFromParts(Object? rawAddress) {
    if (rawAddress is! Map) return null;

    final address = rawAddress.cast<String, dynamic>();
    final parts = <String>[
      _firstAddressValue(address, const [
            'road',
            'pedestrian',
            'footway',
            'path',
            'residential',
          ]) ??
          _firstAddressValue(address, const [
            'neighbourhood',
            'suburb',
            'quarter',
          ]) ??
          '',
      _firstAddressValue(address, const [
            'neighbourhood',
            'suburb',
            'quarter',
            'city',
            'town',
            'village',
          ]) ??
          '',
      _firstAddressValue(address, const [
            'city',
            'town',
            'village',
            'county',
            'state',
          ]) ??
          '',
      _firstAddressValue(address, const ['country']) ?? '',
    ];

    final seen = <String>{};
    final cleaned = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && seen.add(part.toLowerCase()))
        .toList();
    if (cleaned.isEmpty) return null;
    return cleaned.join(', ');
  }

  String? _firstAddressValue(
    Map<String, dynamic> address,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> queryNearbyServices(
    double lat,
    double lng,
  ) async {
    const overpassUrl = 'https://overpass-api.de/api/interpreter';
    final query = '''
[out:json][timeout:15];
(
  node["amenity"="fuel"](around:5000,$lat,$lng);
  way["amenity"="fuel"](around:5000,$lat,$lng);
  node["shop"="car_repair"](around:5000,$lat,$lng);
  way["shop"="car_repair"](around:5000,$lat,$lng);
  node["amenity"="car_repair"](around:5000,$lat,$lng);
  node["shop"="tyres"](around:5000,$lat,$lng);
  node["shop"="tire"](around:5000,$lat,$lng);
  node["amenity"="car_wash"](around:5000,$lat,$lng);
  way["amenity"="car_wash"](around:5000,$lat,$lng);
  node["amenity"="charging_station"](around:5000,$lat,$lng);
  way["amenity"="charging_station"](around:5000,$lat,$lng);
);
out center 30;
''';
    try {
      final response = await _dio.get(
        overpassUrl,
        queryParameters: {'data': query},
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'AutoResQ/1.0 (autoresq@espoch.edu.ec)',
          },
        ),
      );
      final elements = (response.data['elements'] as List?) ?? [];
      return elements.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
