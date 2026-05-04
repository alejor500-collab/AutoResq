import 'package:equatable/equatable.dart';

class AiAnalysis extends Equatable {
  final bool isValidEmergency;
  final String emergencyType;
  final String priority;
  final String userMessage;
  final String safetyRecommendation;
  final String technicianSummary;
  final List<String> detectedRisks;
  final bool requiresImmediateAttention;
  final double confidence;

  const AiAnalysis({
    required this.isValidEmergency,
    required this.emergencyType,
    required this.priority,
    required this.userMessage,
    required this.safetyRecommendation,
    required this.technicianSummary,
    required this.detectedRisks,
    required this.requiresImmediateAttention,
    required this.confidence,
  });

  @override
  List<Object?> get props => [
        isValidEmergency,
        emergencyType,
        priority,
        userMessage,
        safetyRecommendation,
        technicianSummary,
        detectedRisks,
        requiresImmediateAttention,
        confidence,
      ];
}

class Emergency extends Equatable {
  final String id;
  final String usuarioId;
  final String? vehiculoId;
  final int? tipoProblemaId;
  final String descripcion;
  final String? clasificacionIa;
  final String? aiEmergencyType;
  final String? aiPriority;
  final String? aiUserMessage;
  final String? aiSafetyRecommendation;
  final String? aiTechnicianSummary;
  final List<String> aiDetectedRisks;
  final bool? aiRequiresImmediateAttention;
  final double? aiConfidence;
  final String? aiAnalysisStatus;
  final DateTime? aiAnalyzedAt;
  final String
      estado; // pendiente | en_proceso | atendida | finalizada | cancelada
  final DateTime fecha;

  // Joined data (not in emergencias table directly)
  final String? driverName;
  final String? driverPhone;
  final double? lat;
  final double? lng;
  final String? direccion;
  final String? tecnicoId;
  final String? tecnicoUsuarioId;
  final String? tecnicoNombre;
  final String? tecnicoPhone;
  final String? tecnicoSpecialty;
  final double? tecnicoRating;
  final String?
      asignacionEstado; // aceptada | en_ruta | atendiendo | finalizada | rechazada
  final String? asignacionId;
  final DateTime? asignacionFecha;
  final DateTime? asignacionLlegadaFecha;
  final Map<String, dynamic>? priceSnapshot;

  const Emergency({
    required this.id,
    required this.usuarioId,
    this.vehiculoId,
    this.tipoProblemaId,
    required this.descripcion,
    this.clasificacionIa,
    this.aiEmergencyType,
    this.aiPriority,
    this.aiUserMessage,
    this.aiSafetyRecommendation,
    this.aiTechnicianSummary,
    this.aiDetectedRisks = const [],
    this.aiRequiresImmediateAttention,
    this.aiConfidence,
    this.aiAnalysisStatus,
    this.aiAnalyzedAt,
    required this.estado,
    required this.fecha,
    this.driverName,
    this.driverPhone,
    this.lat,
    this.lng,
    this.direccion,
    this.tecnicoId,
    this.tecnicoUsuarioId,
    this.tecnicoNombre,
    this.tecnicoPhone,
    this.tecnicoSpecialty,
    this.tecnicoRating,
    this.asignacionEstado,
    this.asignacionId,
    this.asignacionFecha,
    this.asignacionLlegadaFecha,
    this.priceSnapshot,
  });

  bool get hasTechnician => tecnicoId != null;
  String? get pricingServiceName =>
      priceSnapshot?['service_name'] as String? ?? aiEmergencyType;
  double? get protectedTotal =>
      (priceSnapshot?['protected_total'] as num?)?.toDouble();
  double? get estimatedTotal =>
      (priceSnapshot?['estimated_total'] as num?)?.toDouble();
  String? get pricingStatus => priceSnapshot?['pricing_status'] as String?;

  Emergency copyWith({
    String? id,
    String? usuarioId,
    String? vehiculoId,
    int? tipoProblemaId,
    String? descripcion,
    String? clasificacionIa,
    String? aiEmergencyType,
    String? aiPriority,
    String? aiUserMessage,
    String? aiSafetyRecommendation,
    String? aiTechnicianSummary,
    List<String>? aiDetectedRisks,
    bool? aiRequiresImmediateAttention,
    double? aiConfidence,
    String? aiAnalysisStatus,
    DateTime? aiAnalyzedAt,
    String? estado,
    DateTime? fecha,
    String? driverName,
    String? driverPhone,
    double? lat,
    double? lng,
    String? direccion,
    String? tecnicoId,
    String? tecnicoUsuarioId,
    String? tecnicoNombre,
    String? tecnicoPhone,
    String? tecnicoSpecialty,
    double? tecnicoRating,
    String? asignacionEstado,
    String? asignacionId,
    DateTime? asignacionFecha,
    DateTime? asignacionLlegadaFecha,
    Map<String, dynamic>? priceSnapshot,
  }) {
    return Emergency(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      vehiculoId: vehiculoId ?? this.vehiculoId,
      tipoProblemaId: tipoProblemaId ?? this.tipoProblemaId,
      descripcion: descripcion ?? this.descripcion,
      clasificacionIa: clasificacionIa ?? this.clasificacionIa,
      aiEmergencyType: aiEmergencyType ?? this.aiEmergencyType,
      aiPriority: aiPriority ?? this.aiPriority,
      aiUserMessage: aiUserMessage ?? this.aiUserMessage,
      aiSafetyRecommendation:
          aiSafetyRecommendation ?? this.aiSafetyRecommendation,
      aiTechnicianSummary: aiTechnicianSummary ?? this.aiTechnicianSummary,
      aiDetectedRisks: aiDetectedRisks ?? this.aiDetectedRisks,
      aiRequiresImmediateAttention:
          aiRequiresImmediateAttention ?? this.aiRequiresImmediateAttention,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      aiAnalysisStatus: aiAnalysisStatus ?? this.aiAnalysisStatus,
      aiAnalyzedAt: aiAnalyzedAt ?? this.aiAnalyzedAt,
      estado: estado ?? this.estado,
      fecha: fecha ?? this.fecha,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      direccion: direccion ?? this.direccion,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      tecnicoUsuarioId: tecnicoUsuarioId ?? this.tecnicoUsuarioId,
      tecnicoNombre: tecnicoNombre ?? this.tecnicoNombre,
      tecnicoPhone: tecnicoPhone ?? this.tecnicoPhone,
      tecnicoSpecialty: tecnicoSpecialty ?? this.tecnicoSpecialty,
      tecnicoRating: tecnicoRating ?? this.tecnicoRating,
      asignacionEstado: asignacionEstado ?? this.asignacionEstado,
      asignacionId: asignacionId ?? this.asignacionId,
      asignacionFecha: asignacionFecha ?? this.asignacionFecha,
      asignacionLlegadaFecha:
          asignacionLlegadaFecha ?? this.asignacionLlegadaFecha,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
    );
  }

  @override
  List<Object?> get props => [
        id,
        usuarioId,
        vehiculoId,
        tipoProblemaId,
        descripcion,
        clasificacionIa,
        aiEmergencyType,
        aiPriority,
        aiUserMessage,
        aiSafetyRecommendation,
        aiTechnicianSummary,
        aiDetectedRisks,
        aiRequiresImmediateAttention,
        aiConfidence,
        aiAnalysisStatus,
        aiAnalyzedAt,
        estado,
        fecha,
        driverName,
        driverPhone,
        lat,
        lng,
        direccion,
        tecnicoId,
        tecnicoUsuarioId,
        tecnicoNombre,
        tecnicoPhone,
        tecnicoSpecialty,
        tecnicoRating,
        asignacionEstado,
        asignacionId,
        asignacionFecha,
        asignacionLlegadaFecha,
        priceSnapshot,
      ];
}
