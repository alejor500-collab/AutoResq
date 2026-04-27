import 'dart:convert';

class VehicleModel {
  final String brand;   // Toyota
  final String model;   // Hilux
  final String year;    // 2022
  final String plate;   // ABC-1234
  final String color;   // Blanco

  const VehicleModel({
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.color,
  });

  String get displayName => '$brand $model $year';
  String get displaySub => '$plate • $color';

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'model': model,
        'year': year,
        'plate': plate,
        'color': color,
      };

  factory VehicleModel.fromJson(Map<String, dynamic> j) => VehicleModel(
        brand: j['brand'] ?? '',
        model: j['model'] ?? '',
        year: j['year'] ?? '',
        plate: j['plate'] ?? '',
        color: j['color'] ?? '',
      );

  String toJsonString() => jsonEncode(toJson());

  static VehicleModel? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return VehicleModel.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  VehicleModel copyWith({
    String? brand,
    String? model,
    String? year,
    String? plate,
    String? color,
  }) =>
      VehicleModel(
        brand: brand ?? this.brand,
        model: model ?? this.model,
        year: year ?? this.year,
        plate: plate ?? this.plate,
        color: color ?? this.color,
      );
}
