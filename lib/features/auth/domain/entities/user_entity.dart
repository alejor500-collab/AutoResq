import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class AppUser extends Equatable {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String role; // conductor | tecnico | administrador
  final String? avatarUrl;
  final double rating;
  final int totalServices;
  final bool isActive;
  final bool isAvailable; // solo tecnicos
  final bool isApproved; // solo tecnicos
  final String? specialty; // solo tecnicos
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  final String? verificationStatus; // pendiente | aprobado | rechazado
  final String? rejectionReason;
  final String? accountDisabledReason;
  final String preferredPaymentMethod;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.rating = 0.0,
    this.totalServices = 0,
    this.isActive = true,
    this.isAvailable = false,
    this.isApproved = false,
    this.specialty,
    this.lat,
    this.lng,
    required this.createdAt,
    this.verificationStatus,
    this.rejectionReason,
    this.accountDisabledReason,
    this.preferredPaymentMethod = 'cash',
  });

  bool get isDriver => role == 'conductor';
  bool get isTechnician => role == 'tecnico';
  bool get isAdmin => role == AppConstants.roleAdmin;

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? role,
    String? avatarUrl,
    double? rating,
    int? totalServices,
    bool? isActive,
    bool? isAvailable,
    bool? isApproved,
    String? specialty,
    double? lat,
    double? lng,
    DateTime? createdAt,
    String? verificationStatus,
    String? rejectionReason,
    String? accountDisabledReason,
    String? preferredPaymentMethod,
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
      isActive: isActive ?? this.isActive,
      isAvailable: isAvailable ?? this.isAvailable,
      isApproved: isApproved ?? this.isApproved,
      specialty: specialty ?? this.specialty,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      accountDisabledReason:
          accountDisabledReason ?? this.accountDisabledReason,
      preferredPaymentMethod:
          preferredPaymentMethod ?? this.preferredPaymentMethod,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        phone,
        role,
        avatarUrl,
        rating,
        totalServices,
        isActive,
        isAvailable,
        isApproved,
        specialty,
        lat,
        lng,
        createdAt,
        verificationStatus,
        rejectionReason,
        accountDisabledReason,
        preferredPaymentMethod,
      ];
}
