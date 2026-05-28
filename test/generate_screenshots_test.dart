import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:autoresq/core/constants/app_constants.dart';
import 'package:autoresq/core/errors/failures.dart';
import 'package:autoresq/core/network/dio_client.dart';
import 'package:autoresq/features/admin/presentation/providers/admin_provider.dart';
import 'package:autoresq/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:autoresq/features/admin/presentation/screens/emergency_monitor_screen.dart';
import 'package:autoresq/features/admin/presentation/screens/technician_validation_screen.dart';
import 'package:autoresq/features/admin/presentation/screens/user_management_screen.dart';
import 'package:autoresq/features/auth/domain/entities/user_entity.dart';
import 'package:autoresq/features/auth/domain/repositories/auth_repository.dart';
import 'package:autoresq/features/auth/presentation/screens/account_disabled_screen.dart';
import 'package:autoresq/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:autoresq/features/auth/presentation/screens/login_screen.dart';
import 'package:autoresq/features/auth/presentation/screens/pending_approval_screen.dart';
import 'package:autoresq/features/auth/presentation/screens/register_screen.dart';
import 'package:autoresq/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:autoresq/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:autoresq/features/auth/presentation/screens/splash_screen.dart';
import 'package:autoresq/features/auth/presentation/screens/welcome_screen.dart';
import 'package:autoresq/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:autoresq/features/chat/data/models/message_model.dart';
import 'package:autoresq/features/chat/presentation/providers/chat_provider.dart';
import 'package:autoresq/features/chat/presentation/screens/driver_chat_history_screen.dart';
import 'package:autoresq/features/chat/presentation/screens/driver_chat_screen.dart';
import 'package:autoresq/features/chat/presentation/screens/technician_chat_screen.dart';
import 'package:autoresq/features/emergency/data/datasources/emergency_remote_datasource.dart';
import 'package:autoresq/features/emergency/data/models/emergency_ai_analysis_model.dart';
import 'package:autoresq/features/emergency/data/models/emergency_model.dart';
import 'package:autoresq/features/emergency/data/models/emergency_pricing_model.dart';
import 'package:autoresq/features/emergency/data/services/emergency_pricing_service.dart';
import 'package:autoresq/features/emergency/domain/entities/emergency_entity.dart';
import 'package:autoresq/features/emergency/presentation/providers/emergency_provider.dart';
import 'package:autoresq/features/emergency/presentation/screens/active_service_screen.dart';
import 'package:autoresq/features/emergency/presentation/screens/incoming_request_sheet.dart';
import 'package:autoresq/features/emergency/presentation/screens/create_emergency_screen.dart';
import 'package:autoresq/features/emergency/presentation/screens/driver_home_screen.dart';
import 'package:autoresq/features/emergency/presentation/screens/emergency_status_screen.dart';
import 'package:autoresq/features/emergency/presentation/screens/emergency_history_screen.dart';
import 'package:autoresq/features/emergency/presentation/screens/service_closure_screen.dart';
import 'package:autoresq/features/emergency/presentation/screens/service_completed_screen.dart';
import 'package:autoresq/features/emergency/presentation/screens/technician_home_screen.dart';
import 'package:autoresq/features/map/domain/entities/location_entity.dart';
import 'package:autoresq/features/map/presentation/providers/map_provider.dart';
import 'package:autoresq/features/map/presentation/providers/nearby_services_provider.dart';
import 'package:autoresq/features/profile/data/models/vehicle_model.dart';
import 'package:autoresq/features/profile/presentation/providers/vehicle_provider.dart';
import 'package:autoresq/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:autoresq/features/profile/presentation/screens/edit_vehicle_screen.dart';
import 'package:autoresq/features/profile/presentation/screens/payment_methods_screen.dart';
import 'package:autoresq/features/profile/presentation/screens/profile_screen.dart';
import 'package:autoresq/features/profile/presentation/screens/security_privacy_screen.dart';
import 'package:autoresq/features/ratings/presentation/screens/rate_driver_screen.dart';
import 'package:autoresq/features/ratings/presentation/screens/rate_service_screen.dart';
import 'package:autoresq/shared/providers/auth_provider.dart';
import 'package:autoresq/shared/providers/notification_provider.dart';
import 'package:autoresq/shared/providers/role_provider.dart';
import 'package:autoresq/shared/providers/tecnico_status_provider.dart';
import 'package:autoresq/shared/providers/technician_stats_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDevice = Size(390, 844);
  final now = DateTime(2026, 5, 27, 10, 30);
  final driverUser = AppUser(
    id: 'driver-1',
    email: 'driver@autoresq.test',
    name: 'Carlos Andrade',
    phone: '0991234567',
    role: AppConstants.roleDriver,
    isApproved: true,
    isActive: true,
    createdAt: DateTime(2026, 1, 10),
  );
  final technicianUser = AppUser(
    id: 'tech-user-1',
    email: 'tech@autoresq.test',
    name: 'Luis Mena',
    phone: '0987654321',
    role: AppConstants.roleTechnician,
    specialty: 'mecanica',
    isApproved: true,
    isAvailable: true,
    rating: 4.8,
    totalServices: 126,
    isActive: true,
    createdAt: DateTime(2025, 11, 2),
  );
  final pendingTechnicianUser = AppUser(
    id: 'tech-user-2',
    email: 'review@autoresq.test',
    name: 'Andrea Viteri',
    phone: '0970001111',
    role: AppConstants.roleTechnician,
    specialty: 'grua',
    isApproved: false,
    isActive: true,
    verificationStatus: AppConstants.verificationPending,
    createdAt: DateTime(2026, 5, 20),
  );
  final adminUser = AppUser(
    id: 'admin-1',
    email: 'admin@autoresq.test',
    name: 'Valeria Admin',
    phone: '0995550001',
    role: AppConstants.roleAdmin,
    isApproved: true,
    isActive: true,
    createdAt: DateTime(2025, 8, 15),
  );
  final disabledDriverUser = AppUser(
    id: 'driver-disabled-1',
    email: 'disabled@autoresq.test',
    name: 'Daniela Torres',
    phone: '0984441212',
    role: AppConstants.roleDriver,
    isApproved: true,
    isActive: false,
    accountDisabledReason:
        'Se detecto uso indebido de la cuenta mientras estaba en revision.',
    createdAt: DateTime(2026, 2, 3),
  );
  const mapLocation = LocationEntity(
    lat: -2.189412,
    lng: -79.889066,
    address: 'Av. Francisco de Orellana y Plaza Dañín, Guayaquil',
  );
  final nearbyServices = <NearbyService>[
    const NearbyService(
      name: 'Mecánica Express Norte',
      category: ServiceCategory.carRepair,
      lat: -2.1902,
      lng: -79.8882,
      distanceKm: 0.4,
    ),
    const NearbyService(
      name: 'Vulcanizadora 24/7',
      category: ServiceCategory.tires,
      lat: -2.1885,
      lng: -79.8903,
      distanceKm: 0.7,
    ),
    const NearbyService(
      name: 'Gasolinera Central',
      category: ServiceCategory.fuel,
      lat: -2.1920,
      lng: -79.8920,
      distanceKm: 1.2,
    ),
  ];
  final historyEmergencies = <EmergencyModel>[
    EmergencyModel(
      id: 'history-1',
      usuarioId: driverUser.id,
      descripcion: 'Cambio de llanta por pinchazo en rueda delantera',
      estado: AppConstants.statusCompleted,
      fecha: now.subtract(const Duration(days: 2)),
      direccion: 'Urdesa Central, Guayaquil',
      tecnicoNombre: 'Juan Pérez',
      tecnicoSpecialty: 'llantas',
      priceSnapshot: const {
        'service_name': 'Llantas y vulcanización',
        'protected_total': 18.0,
        'pricing_status': 'protected',
      },
    ),
    EmergencyModel(
      id: 'history-2',
      usuarioId: driverUser.id,
      descripcion: 'Auxilio mecánico por batería descargada',
      estado: AppConstants.statusInProgress,
      fecha: now.subtract(const Duration(hours: 6)),
      direccion: 'Kennedy Norte, Guayaquil',
      tecnicoNombre: 'María Cedeño',
      tecnicoSpecialty: 'mecanica',
      priceSnapshot: const {
        'service_name': 'Sistema eléctrico y batería',
        'protected_total': 25.0,
        'pricing_status': 'protected',
      },
    ),
  ];
  final technicianPendingEmergencies = <EmergencyModel>[
    EmergencyModel(
      id: 'pending-1',
      usuarioId: 'driver-2',
      descripcion: 'Necesito grúa por choque leve, el carro no avanza.',
      estado: AppConstants.statusPending,
      fecha: now.subtract(const Duration(minutes: 8)),
      lat: -2.1876,
      lng: -79.8870,
      direccion: 'Alborada, Guayaquil',
      driverName: 'Kevin Zambrano',
      driverPhone: '0998887776',
      clasificacionIa: EmergencyAiAnalysisModel.gruaRemolque,
      aiEmergencyType: EmergencyAiAnalysisModel.gruaRemolque,
      aiPriority: EmergencyAiAnalysisModel.urgenciaAlta,
      aiTechnicianSummary:
          'Unidad inmovilizada luego de un impacto. Requiere traslado en grúa.',
      priceSnapshot: const {
        'service_name': 'Grúa / remolque',
        'pricing_type': 'distance_based',
        'pricing_status': 'pending_destination',
      },
    ),
    EmergencyModel(
      id: 'pending-2',
      usuarioId: 'driver-3',
      descripcion: 'Batería descargada en centro comercial.',
      estado: AppConstants.statusPending,
      fecha: now.subtract(const Duration(minutes: 12)),
      lat: -2.1910,
      lng: -79.8922,
      direccion: 'Mall del Sol, Guayaquil',
      driverName: 'Sofía Rojas',
      driverPhone: '0981112233',
      clasificacionIa: EmergencyAiAnalysisModel.sistemaElectricoBateria,
      aiEmergencyType: EmergencyAiAnalysisModel.sistemaElectricoBateria,
      aiPriority: EmergencyAiAnalysisModel.urgenciaMedia,
      aiTechnicianSummary:
          'Posible batería descargada. Validar carga, bornes y sistema de encendido.',
      priceSnapshot: const {
        'service_name': 'Sistema eléctrico y batería',
        'protected_total': 25.0,
        'pricing_status': 'protected',
      },
    ),
  ];
  final activeTechnicianEmergency = EmergencyModel(
    id: 'active-tech-1',
    usuarioId: driverUser.id,
    descripcion: 'Auxilio mecánico en avenida principal, no enciende.',
    estado: AppConstants.statusInProgress,
    fecha: now.subtract(const Duration(minutes: 35)),
    lat: mapLocation.lat,
    lng: mapLocation.lng,
    direccion: mapLocation.address,
    driverName: driverUser.name,
    driverPhone: driverUser.phone,
    tecnicoId: 'tech-profile-1',
    tecnicoUsuarioId: technicianUser.id,
    tecnicoNombre: technicianUser.name,
    tecnicoPhone: technicianUser.phone,
    tecnicoSpecialty: technicianUser.specialty,
    tecnicoRating: technicianUser.rating,
    asignacionEstado: AppConstants.assignEnRoute,
    asignacionId: 'assign-1',
    asignacionFecha: now.subtract(const Duration(minutes: 25)),
    priceSnapshot: const {
      'service_name': 'Mecánica rápida',
      'protected_total': 30.0,
      'pricing_status': 'protected',
    },
  );
  final technicianHistory = <EmergencyModel>[
    activeTechnicianEmergency,
    EmergencyModel(
      id: 'tech-history-1',
      usuarioId: 'driver-4',
      descripcion: 'Cambio de llanta en vía a Samborondón.',
      estado: AppConstants.statusCompleted,
      fecha: now.subtract(const Duration(days: 1)),
      direccion: 'Vía Samborondón km 2.5',
      driverName: 'Marcela Mora',
      tecnicoId: 'tech-profile-1',
      tecnicoUsuarioId: technicianUser.id,
      tecnicoNombre: technicianUser.name,
      tecnicoSpecialty: technicianUser.specialty,
      asignacionEstado: AppConstants.assignFinished,
      priceSnapshot: const {
        'service_name': 'Llantas y vulcanización',
        'protected_total': 18.0,
        'pricing_status': 'protected',
      },
    ),
  ];
  const vehicle = VehicleModel(
    id: 'vehicle-1',
    brand: 'Kia',
    model: 'Rio',
    year: '2018',
    plate: 'GBA-1845',
    color: 'Gris',
  );
  final pendingOffersEmergency = EmergencyModel(
    id: 'driver-pending-1',
    usuarioId: driverUser.id,
    descripcion: 'Necesito ayuda con grua para mover el vehiculo al taller.',
    estado: AppConstants.statusPending,
    fecha: now.subtract(const Duration(minutes: 6)),
    lat: mapLocation.lat,
    lng: mapLocation.lng,
    direccion: mapLocation.address,
    driverName: driverUser.name,
    driverPhone: driverUser.phone,
    aiEmergencyType: EmergencyAiAnalysisModel.gruaRemolque,
    clasificacionIa: EmergencyAiAnalysisModel.gruaRemolque,
    aiPriority: EmergencyAiAnalysisModel.urgenciaAlta,
    aiTechnicianSummary:
        'Vehiculo inmovilizado. Esperando ofertas de tecnicos cercanos.',
    priceSnapshot: const {
      'service_name': 'Grua / remolque',
      'service_code': 'tow_service',
      'pricing_type': 'distance_based',
      'pricing_status': 'pending_destination',
      'destination_lat': -2.2031,
      'destination_lng': -79.8802,
    },
  );
  final driverAcceptedEmergency = EmergencyModel(
    id: 'driver-active-1',
    usuarioId: driverUser.id,
    descripcion: 'La bateria no responde y el carro quedo apagado.',
    estado: AppConstants.statusInProgress,
    fecha: now.subtract(const Duration(minutes: 22)),
    lat: mapLocation.lat,
    lng: mapLocation.lng,
    direccion: mapLocation.address,
    driverName: driverUser.name,
    driverPhone: driverUser.phone,
    tecnicoId: 'tech-profile-1',
    tecnicoUsuarioId: technicianUser.id,
    tecnicoNombre: technicianUser.name,
    tecnicoPhone: technicianUser.phone,
    tecnicoSpecialty: technicianUser.specialty,
    tecnicoRating: technicianUser.rating,
    asignacionId: 'assign-driver-1',
    asignacionEstado: AppConstants.assignEnRoute,
    asignacionFecha: now.subtract(const Duration(minutes: 18)),
    acceptedOfferAmount: 32,
    priceSnapshot: const {
      'service_name': 'Sistema electrico y bateria',
      'protected_total': 32.0,
      'pricing_status': 'protected',
    },
  );
  final completedDriverEmergency = driverAcceptedEmergency.copyWith(
    id: 'driver-completed-1',
    estado: AppConstants.statusCompleted,
    asignacionEstado: AppConstants.assignFinished,
    acceptedOfferAmount: 32,
  );
  final technicianLiveLocation = TechnicianLiveLocation(
    lat: -2.1864,
    lng: -79.8858,
    updatedAt: now.subtract(const Duration(minutes: 1)),
  );
  final routeToDriver = RouteEstimate(
    points: [
      LatLng(-2.1864, -79.8858),
      LatLng(-2.1881, -79.8874),
      LatLng(-2.189412, -79.889066),
    ],
    distanceKm: 1.4,
    durationMinutes: 6,
    source: 'golden',
    isApproximate: false,
  );
  final towRoute = RouteEstimate(
    points: [
      LatLng(-2.189412, -79.889066),
      LatLng(-2.1940, -79.8845),
      LatLng(-2.2031, -79.8802),
    ],
    distanceKm: 2.6,
    durationMinutes: 10,
    source: 'golden',
    isApproximate: false,
  );
  final technicianOffers = <TechnicianOffer>[
    TechnicianOffer(
      id: 'offer-1',
      emergencyId: pendingOffersEmergency.id,
      technicianId: 'tech-profile-1',
      technicianUserId: technicianUser.id,
      name: technicianUser.name,
      phone: technicianUser.phone,
      specialty: 'Mecanica rapida',
      rating: 4.8,
      totalServices: 126,
      lat: -2.1864,
      lng: -79.8858,
      distanceKm: 1.4,
      etaMinutes: 6,
      offeredAmount: 32,
      status: 'pendiente',
      createdAt: now.subtract(const Duration(minutes: 4)),
    ),
    TechnicianOffer(
      id: 'offer-2',
      emergencyId: 'driver-pending-1',
      technicianId: 'tech-profile-2',
      technicianUserId: 'tech-user-3',
      name: 'Mario Torres',
      phone: '0965552233',
      specialty: 'Grua / remolque',
      rating: 4.6,
      totalServices: 88,
      lat: -2.1844,
      lng: -79.8831,
      distanceKm: 2.1,
      etaMinutes: 9,
      offeredAmount: 38,
      status: 'pendiente',
      createdAt: DateTime(2026, 5, 27, 10, 23),
    ),
  ];
  final chatMessages = <MessageModel>[
    MessageModel(
      id: 'msg-1',
      asignacionId: 'assign-driver-1',
      remitenteId: driverUser.id,
      contenido: 'Hola, estoy frente a la gasolinera.',
      fechaEnvio: now.subtract(const Duration(minutes: 7)),
      remitenteNombre: driverUser.name,
    ),
    MessageModel(
      id: 'msg-2',
      asignacionId: 'assign-driver-1',
      remitenteId: technicianUser.id,
      contenido: 'Voy en camino, llego en unos minutos.',
      entregadoAt: now.subtract(const Duration(minutes: 5)),
      leidoAt: now.subtract(const Duration(minutes: 4)),
      fechaEnvio: now.subtract(const Duration(minutes: 5)),
      remitenteNombre: technicianUser.name,
    ),
    MessageModel(
      id: 'msg-3',
      asignacionId: 'assign-driver-1',
      remitenteId: driverUser.id,
      contenido: 'Perfecto, te espero aqui mismo.',
      entregadoAt: now.subtract(const Duration(minutes: 3)),
      leidoAt: now.subtract(const Duration(minutes: 2)),
      fechaEnvio: now.subtract(const Duration(minutes: 3)),
      remitenteNombre: driverUser.name,
    ),
  ];
  final latestReactivationRequest = <String, dynamic>{
    'id': 'reactivation-1',
    'reason':
        'Quiero reactivar mi cuenta porque ya entregue los documentos correctos.',
    'status': 'pending',
    'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
    'evidence_url': 'https://example.com/evidence.png',
    'evidence_file_name': 'cedula.png',
  };
  final adminState = AdminState(
    stats: const {
      'total_users': 512,
      'active_users': 487,
      'disabled_users': 25,
      'new_users_7d': 41,
      'new_users_30d': 116,
      'approved_technicians': 86,
      'available_technicians': 31,
      'pending_validations': 4,
      'rejected_technicians': 6,
      'active_emergencies': 14,
      'completion_rate': 82,
      'avg_technician_rating': 4.7,
      'avg_services_per_technician': 18.5,
      'growth_7d': [
        {'label': '21/5', 'count': 4},
        {'label': '22/5', 'count': 6},
        {'label': '23/5', 'count': 5},
        {'label': '24/5', 'count': 7},
        {'label': '25/5', 'count': 4},
        {'label': '26/5', 'count': 8},
        {'label': '27/5', 'count': 7},
      ],
      'role_distribution': [
        {'label': 'Conductores', 'count': 410},
        {'label': 'Tecnicos', 'count': 86},
        {'label': 'Admins', 'count': 16},
      ],
      'alerts': [
        {'label': 'Validaciones pendientes', 'count': 4, 'tone': 'warning'},
        {'label': 'Cuentas desactivadas', 'count': 25, 'tone': 'danger'},
      ],
      'suggestions': [
        'Revisar tecnicos pendientes para aumentar la capacidad operativa.',
        'Hay poca cobertura tecnica disponible frente a la demanda activa.',
      ],
    },
    users: [
      {
        'id': driverUser.id,
        'nombre': driverUser.name,
        'email': driverUser.email,
        'rol': AppConstants.roleDriver,
        'activo': true,
        'avatar_url': null,
        'admin_rating_average': 4.9,
        'admin_services_count': 12,
        'admin_service_history': [
          {
            'service_name': 'Grua / remolque',
            'date': now.subtract(const Duration(days: 2)).toIso8601String(),
            'rating': 5,
            'role_label': 'Conductor',
            'counterpart_label': 'atendido por',
            'counterpart_name': technicianUser.name,
          },
        ],
      },
      {
        'id': technicianUser.id,
        'nombre': technicianUser.name,
        'email': technicianUser.email,
        'rol': AppConstants.roleTechnician,
        'activo': true,
        'tecnicos': [
          {'estado_verificacion': AppConstants.verificationApproved}
        ],
        'admin_rating_average': 4.8,
        'admin_services_count': 126,
        'admin_service_history': [
          {
            'service_name': 'Mecanica rapida',
            'date': now.subtract(const Duration(days: 1)).toIso8601String(),
            'rating': 5,
            'role_label': 'Tecnico',
            'counterpart_label': 'atendio a',
            'counterpart_name': driverUser.name,
          },
        ],
      },
      {
        'id': disabledDriverUser.id,
        'nombre': disabledDriverUser.name,
        'email': disabledDriverUser.email,
        'rol': AppConstants.roleDriver,
        'activo': false,
        'account_disabled_reason': disabledDriverUser.accountDisabledReason,
        'account_reactivation_requests': [latestReactivationRequest],
      },
    ],
    pendingTechnicians: const [
      {
        'id': 'tech-profile-pending-1',
        'especialidad': 'Mecanico',
        'usuarios': {
          'nombre': 'Andrea Viteri',
          'email': 'review@autoresq.test',
          'telefono': '0970001111',
        },
      },
    ],
    emergencies: [
      {
        'id': pendingOffersEmergency.id,
        'descripcion': pendingOffersEmergency.descripcion,
        'fecha': pendingOffersEmergency.fecha.toIso8601String(),
        'estado': pendingOffersEmergency.estado,
        'clasificacion_ia': pendingOffersEmergency.clasificacionIa,
        'ai_priority': pendingOffersEmergency.aiPriority,
        'ai_emergency_type': pendingOffersEmergency.aiEmergencyType,
        'ai_technician_summary': pendingOffersEmergency.aiTechnicianSummary,
        'usuarios': {'nombre': driverUser.name},
        'ubicaciones': [
          {'direccion': pendingOffersEmergency.direccion}
        ],
        'asignaciones': const [],
      },
      {
        'id': driverAcceptedEmergency.id,
        'descripcion': driverAcceptedEmergency.descripcion,
        'fecha': driverAcceptedEmergency.fecha.toIso8601String(),
        'estado': driverAcceptedEmergency.estado,
        'clasificacion_ia': driverAcceptedEmergency.clasificacionIa,
        'ai_priority': driverAcceptedEmergency.aiPriority,
        'ai_emergency_type': driverAcceptedEmergency.aiEmergencyType,
        'ai_technician_summary': driverAcceptedEmergency.aiTechnicianSummary,
        'usuarios': {'nombre': driverUser.name},
        'ubicaciones': [
          {'direccion': driverAcceptedEmergency.direccion}
        ],
        'asignaciones': [
          {
            'estado': driverAcceptedEmergency.asignacionEstado,
            'tecnicos': {
              'usuarios': {'nombre': technicianUser.name}
            },
          },
        ],
      },
    ],
  );

  setUpAll(() async {
    HttpOverrides.global = _GoldenHttpOverrides();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async {
        if (call.method == 'isLocationServiceEnabled') return false;
        if (call.method == 'checkPermission') return 1;
        if (call.method == 'requestPermission') return 1;
        return null;
      },
    );
    FlutterSecureStorage.setMockInitialValues({});
    await loadAppFonts();
    await initializeDateFormatting('es');
  });

  testGoldens('Genera capturas principales de AutoResQ', (tester) async {
    final baseDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: driverUser,
      history: historyEmergencies,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'welcome_screen',
      widget: const WelcomeScreen(),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'login_screen',
      widget: const LoginScreen(),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
      afterPump: (tester) async {
        await tester.tap(find.byKey(const ValueKey('email_toggle')));
        await tester.pumpAndSettle();
      },
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'register_driver_screen',
      widget: const RegisterScreen(initialRole: 0),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'register_technician_screen',
      widget: const RegisterScreen(initialRole: 1),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'driver_home_screen',
      widget: const DriverHomeScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'create_emergency_screen',
      widget: const CreateEmergencyScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'tow_request_screen',
      widget: const CreateEmergencyScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: driverUser,
        history: historyEmergencies,
        analysisResolver: _towAnalysis,
        quoteResolver: _towQuote,
      ),
      afterPump: (tester) async {
        await _openDiagnosticStep(
          tester,
          description:
              'Choqué el carro y necesito grúa para llevarlo al taller porque no rueda.',
        );
      },
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'tire_request_screen',
      widget: const CreateEmergencyScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: driverUser,
        history: historyEmergencies,
        analysisResolver: _tireAnalysis,
        quoteResolver: _tireQuote,
      ),
      afterPump: (tester) async {
        await _openDiagnosticStep(
          tester,
          description:
              'Se pinchó la llanta delantera y necesito ayuda para cambiarla.',
        );
      },
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'mechanic_request_screen',
      widget: const CreateEmergencyScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: driverUser,
        history: historyEmergencies,
        analysisResolver: _mechanicAnalysis,
        quoteResolver: _mechanicQuote,
      ),
      afterPump: (tester) async {
        await _openDiagnosticStep(
          tester,
          description:
              'El vehículo se apagó en plena vía y ya no enciende aunque la batería tiene carga.',
        );
      },
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'emergency_history_screen',
      widget: const EmergencyHistoryScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'pending_approval_screen',
      widget: const PendingApprovalScreen(),
      user: pendingTechnicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: pendingTechnicianUser,
        history: const [],
      ),
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'technician_home_map_screen',
      widget: const TechnicianHomeScreen(initialTab: 2),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: technicianUser,
        history: technicianHistory,
      ),
      technicianStats: const TechnicianStats(
        rating: 4.8,
        totalServices: 126,
        isAvailable: true,
      ),
      technicianPending: technicianPendingEmergencies,
      activeTechnicianEmergency: activeTechnicianEmergency,
      technicianHistory: technicianHistory,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'technician_requests_screen',
      widget: const TechnicianHomeScreen(initialTab: 1),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: technicianUser,
        history: technicianHistory,
      ),
      technicianStats: const TechnicianStats(
        rating: 4.8,
        totalServices: 126,
        isAvailable: true,
      ),
      technicianPending: technicianPendingEmergencies,
      activeTechnicianEmergency: activeTechnicianEmergency,
      technicianHistory: technicianHistory,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'technician_history_screen',
      widget: const TechnicianHomeScreen(initialTab: 0),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: technicianUser,
        history: technicianHistory,
      ),
      technicianStats: const TechnicianStats(
        rating: 4.8,
        totalServices: 126,
        isAvailable: true,
      ),
      technicianPending: technicianPendingEmergencies,
      activeTechnicianEmergency: activeTechnicianEmergency,
      technicianHistory: technicianHistory,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'incoming_request_sheet',
      widget: Scaffold(
        body: IncomingRequestSheet(
          emergency: technicianPendingEmergencies.first,
        ),
      ),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: technicianUser,
        history: technicianHistory,
      ),
      technicianStats: const TechnicianStats(
        rating: 4.8,
        totalServices: 126,
        isAvailable: true,
      ),
      technicianPending: technicianPendingEmergencies,
      activeTechnicianEmergency: activeTechnicianEmergency,
      technicianHistory: technicianHistory,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'service_completed_screen',
      widget: const ServiceCompletedScreen(
        extra: {
          'driverName': 'Carlos Andrade',
          'vehicleInfo': 'Kia Rio 2018 · Gris',
          'duration': '32 min',
          'amount': '\$30.00',
          'techRating': 5,
          'emergencyType': 'Mecánica rápida',
        },
      ),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: technicianUser,
        history: technicianHistory,
      ),
    );
  }, skip: true);

  testGoldens('Capturas auth y home conductor', (tester) async {
    final baseDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: driverUser,
      history: historyEmergencies,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'welcome_screen',
      widget: const WelcomeScreen(),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'login_screen',
      widget: const LoginScreen(),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
      afterPump: (tester) async {
        await tester.tap(find.byKey(const ValueKey('email_toggle')));
        await _stabilizeFrame(tester);
      },
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'register_driver_screen',
      widget: const RegisterScreen(initialRole: 0),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'register_technician_screen',
      widget: const RegisterScreen(initialRole: 1),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'driver_home_screen',
      widget: const DriverHomeScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );
  });

  testGoldens('Capturas flujo conductor', (tester) async {
    final baseDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: driverUser,
      history: historyEmergencies,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'create_emergency_screen',
      widget: const CreateEmergencyScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'tow_request_screen',
      widget: const CreateEmergencyScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: driverUser,
        history: historyEmergencies,
        analysisResolver: _towAnalysis,
        quoteResolver: _towQuote,
      ),
      afterPump: (tester) async {
        await _openDiagnosticStep(
          tester,
          description:
              'ChoquÃ© el carro y necesito grÃºa para llevarlo al taller porque no rueda.',
        );
      },
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'tire_request_screen',
      widget: const CreateEmergencyScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: driverUser,
        history: historyEmergencies,
        analysisResolver: _tireAnalysis,
        quoteResolver: _tireQuote,
      ),
      afterPump: (tester) async {
        await _openDiagnosticStep(
          tester,
          description:
              'Se pinchÃ³ la llanta delantera y necesito ayuda para cambiarla.',
        );
      },
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'mechanic_request_screen',
      widget: const CreateEmergencyScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: driverUser,
        history: historyEmergencies,
        analysisResolver: _mechanicAnalysis,
        quoteResolver: _mechanicQuote,
      ),
      afterPump: (tester) async {
        await _openDiagnosticStep(
          tester,
          description:
              'El vehÃ­culo se apagÃ³ en plena vÃ­a y ya no enciende aunque la baterÃ­a tiene carga.',
        );
      },
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'emergency_history_screen',
      widget: const EmergencyHistoryScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: baseDataSource,
    );
  });

  testGoldens('Capturas rol tecnico', (tester) async {
    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'pending_approval_screen',
      widget: const PendingApprovalScreen(),
      user: pendingTechnicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: pendingTechnicianUser,
        history: const [],
      ),
    );

    final technicianDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: technicianUser,
      history: technicianHistory,
    );

    const technicianStatsValue = TechnicianStats(
      rating: 4.8,
      totalServices: 126,
      isAvailable: true,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'technician_home_map_screen',
      widget: const TechnicianHomeScreen(initialTab: 2),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: technicianDataSource,
      technicianStats: technicianStatsValue,
      technicianPending: technicianPendingEmergencies,
      technicianHistory: technicianHistory,
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'technician_requests_screen',
      widget: const TechnicianHomeScreen(initialTab: 1),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: technicianDataSource,
      technicianStats: technicianStatsValue,
      technicianPending: technicianPendingEmergencies,
      technicianHistory: technicianHistory,
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'technician_history_screen',
      widget: const TechnicianHomeScreen(initialTab: 0),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: technicianDataSource,
      technicianStats: technicianStatsValue,
      technicianPending: technicianPendingEmergencies,
      technicianHistory: technicianHistory,
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'incoming_request_sheet',
      widget: Scaffold(
        body: IncomingRequestSheet(
          emergency: technicianPendingEmergencies.first,
        ),
      ),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: technicianDataSource,
      technicianStats: technicianStatsValue,
      technicianPending: technicianPendingEmergencies,
      technicianHistory: technicianHistory,
      goldenPump: _goldenStepPump,
    );
  });

  testGoldens('Captura servicio completado', (tester) async {
    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'service_completed_screen',
      widget: const ServiceCompletedScreen(
        extra: {
          'driverName': 'Carlos Andrade',
          'vehicleInfo': 'Kia Rio 2018 Â· Gris',
          'duration': '32 min',
          'amount': '\$30.00',
          'techRating': 5,
          'emergencyType': 'MecÃ¡nica rÃ¡pida',
        },
      ),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: technicianUser,
        history: technicianHistory,
      ),
    );
  });

  testGoldens('Capturas auth secundario', (tester) async {
    final disabledDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: disabledDriverUser,
      history: const [],
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'splash_screen',
      widget: const SplashScreen(),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: disabledDataSource,
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'role_selection_screen',
      widget: const RoleSelectionScreen(),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: disabledDataSource,
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'forgot_password_screen',
      widget: const ForgotPasswordScreen(),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: disabledDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'reset_password_screen',
      widget: const ResetPasswordScreen(),
      user: null,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: disabledDataSource,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'account_disabled_screen',
      widget: const AccountDisabledScreen(),
      user: disabledDriverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: disabledDataSource,
      latestReactivationRequestData: latestReactivationRequest,
    );
  });

  testGoldens('Capturas flujo conductor avanzado', (tester) async {
    final driverDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: driverUser,
      history: [
        pendingOffersEmergency,
        driverAcceptedEmergency,
        completedDriverEmergency,
        ...historyEmergencies,
      ],
      offersByEmergencyId: {
        pendingOffersEmergency.id: technicianOffers,
      },
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'emergency_status_pending_screen',
      widget: EmergencyStatusScreen(emergencyId: pendingOffersEmergency.id),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: driverDataSource,
      technicianOffersByEmergencyId: {
        pendingOffersEmergency.id: technicianOffers,
      },
      routeEstimates: {
        _routeKey(
          technicianLiveLocation.lat,
          technicianLiveLocation.lng,
          pendingOffersEmergency.lat!,
          pendingOffersEmergency.lng!,
        ): routeToDriver,
        _routeKey(
          pendingOffersEmergency.lat!,
          pendingOffersEmergency.lng!,
          -2.2031,
          -79.8802,
        ): towRoute,
      },
      technicianLiveLocations: {
        'tech-profile-1': technicianLiveLocation,
      },
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'emergency_status_active_screen',
      widget: EmergencyStatusScreen(emergencyId: driverAcceptedEmergency.id),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: driverDataSource,
      technicianLiveLocations: {
        'tech-profile-1': technicianLiveLocation,
      },
      routeEstimates: {
        _routeKey(
          technicianLiveLocation.lat,
          technicianLiveLocation.lng,
          driverAcceptedEmergency.lat!,
          driverAcceptedEmergency.lng!,
        ): routeToDriver,
      },
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'driver_chat_history_screen',
      widget: const DriverChatHistoryScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: driverDataSource,
      driverHistory: [
        driverAcceptedEmergency,
        completedDriverEmergency,
      ],
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'driver_chat_screen',
      widget: DriverChatScreen(emergencyId: driverAcceptedEmergency.id),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: driverDataSource,
      chatDataSource: _FakeChatRemoteDataSource(
        messagesByEmergencyId: {
          driverAcceptedEmergency.id: chatMessages,
        },
        assignmentIdsByEmergencyId: {
          driverAcceptedEmergency.id: 'assign-driver-1',
        },
      ),
      unreadChatCount: 1,
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'rate_service_screen',
      widget: const RateServiceScreen(
        emergencyId: 'driver-completed-1',
        technicianId: 'tech-profile-1',
        technicianName: 'Luis Mena',
      ),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: driverDataSource,
      goldenPump: _goldenStepPump,
    );
  });

  testGoldens('Capturas tecnico avanzado', (tester) async {
    final technicianDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: technicianUser,
      history: [
        driverAcceptedEmergency,
        completedDriverEmergency,
        activeTechnicianEmergency.copyWith(tecnicoId: null),
        ...technicianHistory,
      ],
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'active_service_screen',
      widget: const ActiveServiceScreen(emergencyId: 'active-tech-safe'),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: _FakeEmergencyRemoteDataSource(
        currentUser: technicianUser,
        history: [
          activeTechnicianEmergency.copyWith(
            id: 'active-tech-safe',
            tecnicoId: null,
            acceptedOfferAmount: 30,
          ),
        ],
      ),
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'technician_chat_screen',
      widget: TechnicianChatScreen(emergencyId: driverAcceptedEmergency.id),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: technicianDataSource,
      chatDataSource: _FakeChatRemoteDataSource(
        messagesByEmergencyId: {
          driverAcceptedEmergency.id: chatMessages,
        },
        assignmentIdsByEmergencyId: {
          driverAcceptedEmergency.id: 'assign-driver-1',
        },
      ),
      unreadChatCount: 2,
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'service_closure_screen',
      widget: const ServiceClosureScreen(),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: technicianDataSource,
      routePath: '/service-closure',
      routeExtra: const {
        'emergencyId': 'driver-active-1',
        'asignacionId': 'assign-driver-1',
        'technicianId': 'tech-profile-1',
        'driverId': 'driver-1',
        'driverName': 'Carlos Andrade',
        'vehicleInfo': 'Kia Rio 2018 · Gris',
        'duration': '32 min',
        'clasificacionIa': 'Mecanica rapida',
        'amount': '32.00',
      },
      goldenPump: _goldenStepPump,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'rate_driver_screen',
      widget: const RateDriverScreen(
        emergencyId: 'driver-active-1',
        asignacionId: 'assign-driver-1',
        technicianId: 'tech-profile-1',
        driverId: 'driver-1',
        driverName: 'Carlos Andrade',
        vehicleInfo: 'Kia Rio 2018 · Gris',
        duration: '32 min',
        clasificacionIa: 'Mecanica rapida',
        amount: '32.00',
      ),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: technicianDataSource,
      goldenPump: _goldenStepPump,
    );
  });

  testGoldens('Capturas perfil y ajustes', (tester) async {
    final profileDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: driverUser,
      history: [
        driverAcceptedEmergency,
        completedDriverEmergency,
        ...historyEmergencies,
      ],
    );
    final profileTechnicianDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: technicianUser,
      history: technicianHistory,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'profile_driver_screen',
      widget: const ProfileScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: profileDataSource,
      activeRole: AppConstants.roleDriver,
      profileStats: const ProfileServiceStats(
        total: 12,
        attended: 3,
        completed: 7,
        pending: 2,
      ),
      vehicle: vehicle,
      technicianStatus: const TecnicoStatus(
        estado: AppConstants.verificationPending,
      ),
      driverHistory: [
        driverAcceptedEmergency,
        completedDriverEmergency,
      ],
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'profile_technician_screen',
      widget: const ProfileScreen(),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: profileTechnicianDataSource,
      activeRole: AppConstants.roleTechnician,
      profileStats: const ProfileServiceStats(
        total: 126,
        attended: 8,
        completed: 118,
        pending: 3,
      ),
      vehicle: vehicle,
      technicianStatus: const TecnicoStatus(
        id: 'tech-profile-1',
        estado: AppConstants.verificationApproved,
        especialidad: 'mecanica',
      ),
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'edit_profile_driver_screen',
      widget: const EditProfileScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: profileDataSource,
      vehicle: vehicle,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'edit_profile_technician_screen',
      widget: const EditProfileScreen(),
      user: technicianUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: profileTechnicianDataSource,
      vehicle: vehicle,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'edit_vehicle_screen',
      widget: const EditVehicleScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: profileDataSource,
      vehicle: vehicle,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'payment_methods_screen',
      widget: const PaymentMethodsScreen(),
      user: driverUser.copyWith(preferredPaymentMethod: 'cash'),
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: profileDataSource,
      vehicle: vehicle,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'security_privacy_screen',
      widget: const SecurityPrivacyScreen(),
      user: driverUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: profileDataSource,
      vehicle: vehicle,
    );
  });

  testGoldens('Capturas admin', (tester) async {
    final adminDataSource = _FakeEmergencyRemoteDataSource(
      currentUser: adminUser,
      history: const [],
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'admin_dashboard_screen',
      widget: const AdminDashboardScreen(),
      user: adminUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: adminDataSource,
      adminState: adminState,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'user_management_screen',
      widget: const UserManagementScreen(),
      user: adminUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: adminDataSource,
      adminState: adminState,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'technician_validation_screen',
      widget: const TechnicianValidationScreen(),
      user: adminUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: adminDataSource,
      adminState: adminState,
    );

    await _captureScreen(
      tester,
      surfaceSize: testDevice,
      goldenName: 'emergency_monitor_screen',
      widget: const EmergencyMonitorScreen(),
      user: adminUser,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: adminDataSource,
      adminState: adminState,
    );
  });
}

Future<void> _captureScreen(
  WidgetTester tester, {
  required Size surfaceSize,
  required String goldenName,
  required Widget widget,
  required AppUser? user,
  required LocationEntity mapLocation,
  required List<NearbyService> nearbyServices,
  required _FakeEmergencyRemoteDataSource dataSource,
  TechnicianStats? technicianStats,
  List<Emergency> technicianPending = const [],
  Emergency? activeTechnicianEmergency,
  List<Emergency> technicianHistory = const [],
  List<Emergency> driverHistory = const [],
  String? activeRole,
  ProfileServiceStats? profileStats,
  TecnicoStatus? technicianStatus,
  VehicleModel? vehicle,
  Map<String, List<TechnicianOffer>> technicianOffersByEmergencyId = const {},
  Map<String, TechnicianLiveLocation> technicianLiveLocations = const {},
  Map<RouteEstimateArgs, RouteEstimate> routeEstimates = const {},
  ChatRemoteDataSource? chatDataSource,
  int unreadChatCount = 0,
  Map<String, dynamic>? latestReactivationRequestData,
  AdminState? adminState,
  String? routePath,
  Object? routeExtra,
  Future<void> Function(WidgetTester tester)? goldenPump,
  Future<void> Function(WidgetTester tester)? afterPump,
}) async {
  await tester.pumpWidgetBuilder(
    _buildTestApp(
      widget: KeyedSubtree(
        key: ValueKey(goldenName),
        child: widget,
      ),
      scopeKey: goldenName,
      user: user,
      mapLocation: mapLocation,
      nearbyServices: nearbyServices,
      dataSource: dataSource,
      technicianStats: technicianStats,
      technicianPending: technicianPending,
      activeTechnicianEmergency: activeTechnicianEmergency,
      technicianHistory: technicianHistory,
      driverHistory: driverHistory,
      activeRole: activeRole,
      profileStats: profileStats,
      technicianStatus: technicianStatus,
      vehicle: vehicle,
      technicianOffersByEmergencyId: technicianOffersByEmergencyId,
      technicianLiveLocations: technicianLiveLocations,
      routeEstimates: routeEstimates,
      chatDataSource: chatDataSource,
      unreadChatCount: unreadChatCount,
      latestReactivationRequestData: latestReactivationRequestData,
      adminState: adminState,
      routePath: routePath,
      routeExtra: routeExtra,
    ),
    surfaceSize: surfaceSize,
  );
  await _stabilizeFrame(tester);
  if (afterPump != null) {
    await afterPump(tester);
  }
  await _stabilizeFrame(tester);
  await screenMatchesGolden(
    tester,
    goldenName,
    customPump: goldenPump,
  );
}

Widget _buildTestApp({
  required Widget widget,
  required String scopeKey,
  required AppUser? user,
  required LocationEntity mapLocation,
  required List<NearbyService> nearbyServices,
  required _FakeEmergencyRemoteDataSource dataSource,
  TechnicianStats? technicianStats,
  List<Emergency> technicianPending = const [],
  Emergency? activeTechnicianEmergency,
  List<Emergency> technicianHistory = const [],
  List<Emergency> driverHistory = const [],
  String? activeRole,
  ProfileServiceStats? profileStats,
  TecnicoStatus? technicianStatus,
  VehicleModel? vehicle,
  Map<String, List<TechnicianOffer>> technicianOffersByEmergencyId = const {},
  Map<String, TechnicianLiveLocation> technicianLiveLocations = const {},
  Map<RouteEstimateArgs, RouteEstimate> routeEstimates = const {},
  ChatRemoteDataSource? chatDataSource,
  int unreadChatCount = 0,
  Map<String, dynamic>? latestReactivationRequestData,
  AdminState? adminState,
  String? routePath,
  Object? routeExtra,
}) {
  const statsUserId = 'tech-user-1';
  MediaQuery mediaWrapper(BuildContext context, Widget? child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        devicePixelRatio: 3,
        padding: const EdgeInsets.only(top: 47, bottom: 34),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
  final child = routePath == null
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              devicePixelRatio: 3,
              padding: EdgeInsets.only(top: 47, bottom: 34),
              viewPadding: EdgeInsets.only(top: 47, bottom: 34),
            ),
            child: widget,
          ),
        )
      : MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: GoRouter(
            initialLocation: routePath,
            initialExtra: routeExtra,
            routes: [
              GoRoute(
                path: routePath,
                builder: (context, state) => widget,
              ),
            ],
          ),
          builder: mediaWrapper,
        );
  return ProviderScope(
    key: ValueKey('scope-$scopeKey'),
    overrides: [
      supabaseClientProvider.overrideWithValue(_FakeSupabaseClient()),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(user)),
      authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(user)),
      authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(user)),
      passwordRecoveryProvider.overrideWith((ref) => Stream<bool>.value(false)),
      notificationsProvider.overrideWith((ref) => Stream.value(const [])),
      unreadChatCountProvider.overrideWith(
        (ref) => Stream<int>.value(unreadChatCount),
      ),
      emergencyDataSourceProvider.overrideWithValue(dataSource),
      emergencyPricingServiceProvider.overrideWithValue(
        _FakeEmergencyPricingService(
          quoteResolver: dataSource.quoteResolver,
        ),
      ),
      if (chatDataSource != null)
        chatDataSourceProvider.overrideWithValue(chatDataSource),
      mapNotifierProvider.overrideWith(
        (ref) => _FakeMapNotifier(
          const MapState().copyWith(
            currentLocation: mapLocation,
            isLoading: false,
            error: null,
            zoom: 14.5,
          ),
        ),
      ),
      nearbyServicesProvider.overrideWith((ref, coords) async => nearbyServices),
      technicianStatsProvider(statsUserId).overrideWith(
        (ref) => Stream.value(technicianStats ?? const TechnicianStats.empty()),
      ),
      technicianPendingEmergenciesProvider.overrideWith(
        (ref) => Stream.value(technicianPending),
      ),
      activeTechnicianEmergencyProvider.overrideWith(
        (ref) => Stream.value(activeTechnicianEmergency),
      ),
      technicianEmergencyHistoryProvider.overrideWith(
        (ref) => Future.value(technicianHistory),
      ),
      driverEmergencyHistoryProvider.overrideWith(
        (ref) => Future.value(driverHistory),
      ),
      if (activeRole != null)
        activeRoleProvider.overrideWith(
          (ref) => ActiveRoleNotifier(activeRole),
        ),
      if (profileStats != null)
        profileServiceStatsProvider(
          (userId: user?.id ?? '', isTechnician: activeRole == AppConstants.roleTechnician),
        ).overrideWith((ref) async => profileStats),
      if (technicianStatus != null)
        tecnicoStatusProvider.overrideWith((ref) async => technicianStatus),
      if (vehicle != null)
        vehicleProvider.overrideWith(
          (ref) => _FakeVehicleNotifier(vehicle),
        ),
      for (final entry in technicianOffersByEmergencyId.entries)
        technicianOffersProvider(entry.key).overrideWith(
          (ref) => Stream.value(entry.value),
        ),
      for (final entry in technicianLiveLocations.entries)
        technicianLiveLocationProvider(entry.key).overrideWith(
          (ref) => Stream.value(entry.value),
        ),
      for (final entry in routeEstimates.entries)
        technicianRouteEstimateProvider(entry.key).overrideWith(
          (ref) async => entry.value,
        ),
      if (latestReactivationRequestData != null && user != null)
        latestReactivationRequestProvider(user.id).overrideWith(
          (ref) async => latestReactivationRequestData,
        ),
      if (adminState != null)
        adminNotifierProvider.overrideWith(
          (ref) => _FakeAdminNotifier(adminState),
        ),
    ],
    child: child,
  );
}

Future<void> _openDiagnosticStep(
  WidgetTester tester, {
  required String description,
}) async {
  await tester.tap(find.text('Continuar'));
  await _stabilizeFrame(tester);

  final descriptionField = find.byType(TextField).last;
  await tester.enterText(descriptionField, description);
  await _stabilizeFrame(tester);

  await tester.tap(find.text('Analizar con IA'));
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _stabilizeFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _goldenStepPump(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 180));
}

class _GoldenHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _GoldenHttpClient();
  }
}

class _GoldenHttpClient implements HttpClient {
  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _GoldenHttpRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _GoldenHttpRequest();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GoldenHttpRequest implements HttpClientRequest {
  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = false;

  @override
  Future<HttpClientResponse> close() async => _GoldenHttpResponse();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GoldenHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  static final List<int> _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0e0AAAAASUVORK5CYII=',
  );

  @override
  int get contentLength => _pngBytes.length;

  @override
  HttpHeaders get headers => _GoldenHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get statusCode => 200;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_pngBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GoldenHttpHeaders implements HttpHeaders {
  @override
  String? value(String name) {
    if (name.toLowerCase() == HttpHeaders.contentTypeHeader) {
      return 'image/png';
    }
    return null;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RouteEstimateArgs _routeKey(
  double originLat,
  double originLng,
  double destinationLat,
  double destinationLng,
) {
  return (
    originLat: originLat,
    originLng: originLng,
    destinationLat: destinationLat,
    destinationLng: destinationLng,
  );
}

EmergencyAiAnalysisModel _towAnalysis(String description) {
  return const EmergencyAiAnalysisModel(
    categoria: EmergencyAiAnalysisModel.gruaRemolque,
    tipoDanio: 'Vehículo inmovilizado luego de un choque.',
    resumenTecnico:
        'Se recomienda remolque inmediato y revisión estructural al llegar al taller.',
    urgencia: EmergencyAiAnalysisModel.urgenciaAlta,
    requiereGrua: true,
    recomendacion: 'Mantén las luces de emergencia activadas y espera en un lugar seguro.',
    confidence: 0.96,
  );
}

EmergencyPriceQuote _towQuote(
  String emergencyTypeCode,
  double originLat,
  double originLng,
  LocationEntity? destination,
) {
  return EmergencyPriceQuote(
    serviceCode: emergencyTypeCode,
    serviceName: 'Grúa / remolque',
    pricingType: 'distance_based',
    pricingStatus: 'pending_destination',
    basePrice: 20,
    pricePerKm: 1.5,
    originLat: originLat,
    originLng: originLng,
    displayTitle: 'Cuota referencial de grúa',
    displayMessage: 'Desde \$20.00 aprox. + \$1.50/km adicional',
    requiresDestination: true,
    destinationRequiredMessage: 'Selecciona el destino del traslado para calcular la ruta.',
    requiresUserApprovalForExtras: true,
    isEstimate: true,
  );
}

EmergencyAiAnalysisModel _tireAnalysis(String description) {
  return const EmergencyAiAnalysisModel(
    categoria: EmergencyAiAnalysisModel.llantasVulcanizacion,
    tipoDanio: 'Pinchazo en llanta delantera.',
    resumenTecnico:
        'El técnico debe revisar la cubierta, validar si hay repuesto y realizar cambio o reparación.',
    urgencia: EmergencyAiAnalysisModel.urgenciaMedia,
    requiereGrua: false,
    recomendacion: 'Evita seguir conduciendo para no dañar el rin.',
    confidence: 0.93,
  );
}

EmergencyPriceQuote _tireQuote(
  String emergencyTypeCode,
  double originLat,
  double originLng,
  LocationEntity? destination,
) {
  return EmergencyPriceQuote(
    serviceCode: emergencyTypeCode,
    serviceName: 'Llantas y vulcanización',
    pricingType: 'fixed',
    pricingStatus: 'protected',
    basePrice: 18,
    originLat: originLat,
    originLng: originLng,
    estimatedTotal: 18,
    protectedTotal: 18,
    displayTitle: 'Cuota referencial inicial',
    displayMessage: '\$18.00 aprox. por asistencia y cambio básico.',
    requiresDestination: false,
    requiresUserApprovalForExtras: true,
    isEstimate: true,
  );
}

EmergencyAiAnalysisModel _mechanicAnalysis(String description) {
  return const EmergencyAiAnalysisModel(
    categoria: EmergencyAiAnalysisModel.mecanicaRapida,
    tipoDanio: 'Falla mecánica general con motor apagado.',
    resumenTecnico:
        'Se requiere inspección en sitio para determinar si el problema es de encendido, combustible o sobrecalentamiento.',
    urgencia: EmergencyAiAnalysisModel.urgenciaMedia,
    requiereGrua: false,
    recomendacion: 'No intentes encender repetidamente el motor hasta revisar niveles y temperatura.',
    confidence: 0.91,
  );
}

EmergencyPriceQuote _mechanicQuote(
  String emergencyTypeCode,
  double originLat,
  double originLng,
  LocationEntity? destination,
) {
  return EmergencyPriceQuote(
    serviceCode: emergencyTypeCode,
    serviceName: 'Mecánica rápida',
    pricingType: 'diagnostic',
    pricingStatus: 'estimated',
    basePrice: 25,
    originLat: originLat,
    originLng: originLng,
    estimatedTotal: 25,
    protectedTotal: 25,
    displayTitle: 'Cuota referencial de diagnóstico',
    displayMessage: '\$25.00 aprox. La reparación y repuestos se cotizan aparte.',
    requiresDestination: false,
    requiresUserApprovalForExtras: true,
    isEstimate: true,
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.user);

  final AppUser? user;

  @override
  Stream<AppUser?> get authStateChanges => Stream<AppUser?>.value(user);

  @override
  Future<Either<Failure, AppUser?>> getCurrentUser() async => right(user);

  @override
  Future<Either<Failure, AppUser>> login({
    required String email,
    required String password,
  }) async {
    return user != null
        ? right(user!)
        : left(const AuthFailure('Sin usuario de prueba'));
  }

  @override
  Future<Either<Failure, AppUser>> loginWithGoogle() async {
    return user != null
        ? right(user!)
        : left(const AuthFailure('Sin usuario de prueba'));
  }

  @override
  Future<Either<Failure, void>> logout() async => right(null);

  @override
  Future<Either<Failure, AppUser>> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? specialty,
  }) async {
    final registeredUser = AppUser(
      id: 'registered-user',
      email: email,
      name: name,
      phone: phone,
      role: role,
      specialty: specialty,
      isApproved: role == AppConstants.roleDriver,
      isAvailable: false,
      createdAt: DateTime(2026, 5, 27),
    );
    return right(registeredUser);
  }

  @override
  Future<Either<Failure, void>> sendPasswordReset(String email) async =>
      right(null);

  @override
  Future<Either<Failure, void>> updatePassword(String newPassword) async =>
      right(null);

  @override
  Future<Either<Failure, AppUser>> updateProfile(AppUser user) async =>
      right(user);
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(AppUser? user) : super(_FakeAuthRepository(user)) {
    state = AsyncValue.data(user);
  }
}

class _FakeMapNotifier extends MapNotifier {
  _FakeMapNotifier(MapState initialState) : super(DioClient()) {
    state = initialState;
  }

  @override
  Future<void> getCurrentLocation() async {}
}

class _FakeVehicleNotifier extends VehicleNotifier {
  _FakeVehicleNotifier(VehicleModel? vehicle)
      : super(_FakeSupabaseClient(), const FlutterSecureStorage(), null) {
    state = vehicle;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> save(VehicleModel vehicle) async {
    state = vehicle;
  }

  @override
  Future<void> delete() async {
    state = null;
  }
}

class _FakeAdminNotifier extends AdminNotifier {
  _FakeAdminNotifier(AdminState initialState) : super(_FakeSupabaseClient()) {
    state = initialState;
  }

  @override
  Future<void> loadStats() async {}

  @override
  Future<void> loadUsers() async {}

  @override
  Future<void> loadPendingTechnicians() async {}

  @override
  Future<void> loadAllEmergencies() async {}
}

class _FakeChatRemoteDataSource implements ChatRemoteDataSource {
  _FakeChatRemoteDataSource({
    this.messagesByEmergencyId = const {},
    this.assignmentIdsByEmergencyId = const {},
  });

  final Map<String, List<MessageModel>> messagesByEmergencyId;
  final Map<String, String> assignmentIdsByEmergencyId;

  String _emergencyIdFromAssignment(String asignacionId) {
    for (final entry in assignmentIdsByEmergencyId.entries) {
      if (entry.value == asignacionId) return entry.key;
    }
    if (assignmentIdsByEmergencyId.isEmpty) return '';
    return assignmentIdsByEmergencyId.keys.first;
  }

  @override
  Future<String> getAssignmentIdForEmergency(String emergencyId) async {
    return assignmentIdsByEmergencyId[emergencyId] ?? 'assignment-$emergencyId';
  }

  @override
  Future<List<MessageModel>> getMessages(String asignacionId) async {
    final emergencyId = _emergencyIdFromAssignment(asignacionId);
    return messagesByEmergencyId[emergencyId] ?? const [];
  }

  @override
  Future<int> getUnreadMessageCount(String userId) async {
    var count = 0;
    for (final messages in messagesByEmergencyId.values) {
      count += messages.where((message) => !message.isRead).length;
    }
    return count;
  }

  @override
  Future<void> markIncomingAsDelivered(String asignacionId, String userId) async {}

  @override
  Future<void> markIncomingAsRead(String asignacionId, String userId) async {}

  @override
  Future<MessageModel> sendMessage({
    required String asignacionId,
    required String remitenteId,
    required String contenido,
  }) async {
    return MessageModel(
      id: 'sent-message',
      asignacionId: asignacionId,
      remitenteId: remitenteId,
      contenido: contenido,
      fechaEnvio: DateTime(2026, 5, 27, 10, 45),
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> watchMessages(String asignacionId) async* {
    yield const [];
  }
}

class _FakeEmergencyPricingService extends EmergencyPricingService {
  _FakeEmergencyPricingService({required this.quoteResolver})
      : super(_FakeSupabaseClient());

  final EmergencyPriceQuote Function(
    String emergencyTypeCode,
    double originLat,
    double originLng,
    LocationEntity? destination,
  ) quoteResolver;

  @override
  Future<EmergencyPriceQuote> calculateQuote({
    required String emergencyTypeCode,
    required double originLat,
    required double originLng,
    LocationEntity? destination,
  }) async {
    return quoteResolver(
      emergencyTypeCode,
      originLat,
      originLng,
      destination,
    );
  }

  @override
  Future<void> saveSnapshot({
    required String emergencyId,
    required EmergencyPriceQuote quote,
  }) async {}
}

class _FakeEmergencyRemoteDataSource implements EmergencyRemoteDataSource {
  _FakeEmergencyRemoteDataSource({
    required this.currentUser,
    required this.history,
    this.offersByEmergencyId = const {},
    EmergencyAiAnalysisModel Function(String description)? analysisResolver,
    EmergencyPriceQuote Function(
      String emergencyTypeCode,
      double originLat,
      double originLng,
      LocationEntity? destination,
    )? quoteResolver,
  })  : analysisResolver = analysisResolver ?? _mechanicAnalysis,
        quoteResolver = quoteResolver ?? _mechanicQuote;

  final AppUser currentUser;
  final List<EmergencyModel> history;
  final Map<String, List<TechnicianOffer>> offersByEmergencyId;
  final EmergencyAiAnalysisModel Function(String description) analysisResolver;
  final EmergencyPriceQuote Function(
    String emergencyTypeCode,
    double originLat,
    double originLng,
    LocationEntity? destination,
  ) quoteResolver;

  @override
  Future<EmergencyAiAnalysisModel> analyzeEmergency({
    required String description,
    double? lat,
    double? lng,
    String? direccion,
    List<String> evidenceImageUrls = const [],
  }) async {
    return analysisResolver(description);
  }

  @override
  Future<void> acceptTechnicianOffer(String offerId) async {}

  @override
  Future<void> assignTechnician(String emergencyId, String technicianUserId) async {}

  @override
  Future<void> cancelTechnicianService(String emergencyId) async {}

  @override
  Future<EmergencyModel> createEmergency({
    required String usuarioId,
    required String descripcion,
    required double lat,
    required double lng,
    String? direccion,
    String? vehiculoId,
    int? tipoProblemaId,
    EmergencyAiAnalysisModel? aiAnalysis,
    String aiAnalysisStatus = 'pending',
    EmergencyPriceQuote? priceQuote,
    String paymentMethod = 'cash',
    List<EmergencyPhotoUpload> evidencePhotos = const [],
    List<String> evidencePhotoUrls = const [],
  }) async {
    return EmergencyModel(
      id: 'generated-emergency',
      usuarioId: usuarioId,
      descripcion: descripcion,
      estado: AppConstants.statusPending,
      fecha: DateTime(2026, 5, 27, 10, 35),
      direccion: direccion,
      lat: lat,
      lng: lng,
      aiEmergencyType: aiAnalysis?.categoria,
      aiPriority: aiAnalysis?.urgencia,
      aiUserMessage: aiAnalysis?.tipoDanio,
      aiSafetyRecommendation: aiAnalysis?.recomendacion,
      aiTechnicianSummary: aiAnalysis?.resumenTecnico,
      aiConfidence: aiAnalysis?.confidence,
      aiRequiresImmediateAttention: aiAnalysis?.requiresImmediateAttention,
      priceSnapshot: priceQuote?.toSnapshotJson(),
      paymentMethod: paymentMethod,
      evidencePhotoUrls: evidencePhotoUrls,
    );
  }

  @override
  Future<void> createTechnicianOffer(
    String emergencyId, {
    double? offeredAmount,
  }) async {}

  @override
  Future<List<EmergencyModel>> getAllEmergencies() async => history;

  @override
  Future<EmergencyModel?> getActiveDriverEmergency(String userId) async => null;

  @override
  Future<EmergencyModel?> getActiveTechnicianEmergency(
    String technicianUserId,
  ) async =>
      null;

  @override
  Future<List<EmergencyModel>> getDriverEmergencies(String userId) async {
    return history.where((item) => item.usuarioId == userId).toList();
  }

  @override
  Future<EmergencyModel> getEmergency(String id) async {
    return history.firstWhere(
      (item) => item.id == id,
      orElse: () => history.first,
    );
  }

  @override
  Future<Map<String, dynamic>?> getPendingRating({
    required String userId,
    required String role,
  }) async =>
      null;

  @override
  Future<List<EmergencyModel>> getPendingEmergencies() async => const [];

  @override
  Future<List<EmergencyModel>> getPendingEmergenciesForSpecialty(
    String? specialty,
  ) async =>
      const [];

  @override
  Future<List<EmergencyModel>> getTechnicianEmergencies(
    String technicianUserId,
  ) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getTechnicianOffers(String emergencyId) async =>
      (offersByEmergencyId[emergencyId] ?? const [])
          .map(
            (offer) => {
              'id': offer.id,
              'emergencia_id': offer.emergencyId,
              'tecnico_id': offer.technicianId,
              'technician_name': offer.name,
              'technician_phone': offer.phone,
              'specialty': offer.specialty,
              'rating': offer.rating,
              'total_services': offer.totalServices,
              'technician_lat': offer.lat,
              'technician_lng': offer.lng,
              'distancia_km': offer.distanceKm,
              'eta_minutos': offer.etaMinutes,
              'monto_ofertado': offer.offeredAmount,
              'estado': offer.status,
              'fecha_oferta': offer.createdAt.toIso8601String(),
              'tecnicos': {
                'usuario_id': offer.technicianUserId,
                'especialidad': offer.specialty,
                'calificacion_promedio': offer.rating,
                'total_servicios': offer.totalServices,
                'ubicacion_lat': offer.lat,
                'ubicacion_lng': offer.lng,
                'usuarios': {
                  'nombre': offer.name,
                  'telefono': offer.phone,
                },
              },
            },
          )
          .toList();

  @override
  Future<List<Map<String, dynamic>>> getTiposProblema() async => const [];

  @override
  Future<bool> hasPendingRating({
    required String userId,
    required String role,
  }) async =>
      false;

  @override
  Future<void> updateStatus(String id, String estado) async {}

  @override
  Future<List<String>> uploadEmergencyEvidencePhotos({
    required String ownerId,
    required List<EmergencyPhotoUpload> photos,
    String? emergencyId,
  }) async =>
      const [];

  @override
  Stream<List<Map<String, dynamic>>> watchEmergency(String id) =>
      const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> watchPendingEmergencies() =>
      const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> watchTechnicianOfferRows(
    String emergencyId,
  ) =>
      const Stream.empty();
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {}
