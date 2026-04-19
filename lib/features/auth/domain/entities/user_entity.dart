import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String role; // conductor | tecnico | admin
  final String? avatarUrl;
  final double rating;
  final int totalServices;
  final bool isAvailable;   // solo técnicos
  final bool isApproved;    // solo técnicos
  final String? specialty;  // solo técnicos
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.rating = 0.0,
    this.totalServices = 0,
    this.isAvailable = false,
    this.isApproved = false,
    this.specialty,
    this.lat,
    this.lng,
    required this.createdAt,
  });

  bool get isDriver => role == 'conductor';
  bool get isTechnician => role == 'tecnico';
  bool get isAdmin => role == 'admin';

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? role,
    String? avatarUrl,
    double? rating,
    int? totalServices,
    bool? isAvailable,
    bool? isApproved,
    String? specialty,
    double? lat,
    double? lng,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      totalServices: totalServices ?? this.totalServices,
      isAvailable: isAvailable ?? this.isAvailable,
      isApproved: isApproved ?? this.isApproved,
      specialty: specialty ?? this.specialty,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, email, name, phone, role, avatarUrl,
        rating, totalServices, isAvailable, isApproved,
        specialty, lat, lng, createdAt,
      ];
}
