import 'dart:convert';

class VehicleModel {
  final String? id;
  final String? userId;
  final String brand;
  final String model;
  final String year;
  final String plate;
  final String color;

  const VehicleModel({
    this.id,
    this.userId,
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.color,
  });

  String get displayName => '$brand $model $year';
  String get displaySub => '$plate • $color';

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (userId != null) 'usuario_id': userId,
        'brand': brand,
        'model': model,
        'year': year,
        'plate': plate,
        'color': color,
      };

  factory VehicleModel.fromJson(Map<String, dynamic> j) => VehicleModel(
        id: j['id'] as String?,
        userId: j['usuario_id'] as String?,
        brand: j['brand'] ?? j['marca'] ?? '',
        model: j['model'] ?? j['modelo'] ?? '',
        year: (j['anio'] is int
                ? (j['anio'] as int).toString()
                : j['anio']?.toString()) ??
            j['year']?.toString() ??
            '',
        plate: j['plate'] ?? j['placa'] ?? '',
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
    String? id,
    String? userId,
    String? brand,
    String? model,
    String? year,
    String? plate,
    String? color,
  }) =>
      VehicleModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        year: year ?? this.year,
        plate: plate ?? this.plate,
        color: color ?? this.color,
      );
}
