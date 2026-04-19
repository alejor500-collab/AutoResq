import '../../domain/entities/user_entity.dart';

class UserModel extends AppUser {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    required super.phone,
    required super.role,
    super.avatarUrl,
    super.rating,
    super.totalServices,
    super.isAvailable,
    super.isApproved,
    super.specialty,
    super.lat,
    super.lng,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'conductor',
      avatarUrl: json['avatar_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalServices: json['total_services'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? false,
      isApproved: json['is_approved'] as bool? ?? false,
      specialty: json['specialty'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'avatar_url': avatarUrl,
      'rating': rating,
      'total_services': totalServices,
      'is_available': isAvailable,
      'is_approved': isApproved,
      'specialty': specialty,
      'lat': lat,
      'lng': lng,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromEntity(AppUser entity) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      name: entity.name,
      phone: entity.phone,
      role: entity.role,
      avatarUrl: entity.avatarUrl,
      rating: entity.rating,
      totalServices: entity.totalServices,
      isAvailable: entity.isAvailable,
      isApproved: entity.isApproved,
      specialty: entity.specialty,
      lat: entity.lat,
      lng: entity.lng,
      createdAt: entity.createdAt,
    );
  }
}
