class EmergencyAiAnalysisModel {
  static const mecanicaRapida = 'Mecánica rápida';
  static const sistemaElectricoBateria = 'Sistema eléctrico y batería';
  static const llantasVulcanizacion = 'Llantas y vulcanización';
  static const gruaRemolque = 'Grúa / remolque';
  static const combustible = 'Combustible';
  static const cerrajeriaVehicular = 'Cerrajería vehicular';
  static const auxilioGeneral = 'Auxilio general';

  static const urgenciaBaja = 'baja';
  static const urgenciaMedia = 'media';
  static const urgenciaAlta = 'alta';

  static const allowedCategories = {
    mecanicaRapida,
    sistemaElectricoBateria,
    llantasVulcanizacion,
    gruaRemolque,
    combustible,
    cerrajeriaVehicular,
    auxilioGeneral,
  };

  static const allowedUrgencies = {
    urgenciaBaja,
    urgenciaMedia,
    urgenciaAlta,
  };

  final String categoria;
  final String tipoDanio;
  final String resumenTecnico;
  final String urgencia;
  final bool requiereGrua;
  final String recomendacion;
  final double confidence;
  final bool isFallback;

  const EmergencyAiAnalysisModel({
    required this.categoria,
    required this.tipoDanio,
    required this.resumenTecnico,
    required this.urgencia,
    required this.requiereGrua,
    required this.recomendacion,
    this.confidence = 1,
    this.isFallback = false,
  });

  factory EmergencyAiAnalysisModel.fromJson(
    Map<String, dynamic> json, {
    String? fallbackDescription,
  }) {
    if (_looksLikeNewFormat(json)) {
      return _fromNewFormat(json, fallbackDescription: fallbackDescription);
    }
    return _fromLegacyFormat(json, fallbackDescription: fallbackDescription);
  }

  factory EmergencyAiAnalysisModel.fallback(String description) {
    final cleaned = _safeText(description);
    final shortDescription = _truncate(
      cleaned.isEmpty ? 'Solicitud vehicular reportada por el conductor.' : cleaned,
      140,
    );
    return EmergencyAiAnalysisModel(
      categoria: auxilioGeneral,
      tipoDanio: _truncate(
        cleaned.isEmpty ? 'Problema vehicular por confirmar.' : cleaned,
        90,
      ),
      resumenTecnico:
          'Conductor reporta: $shortDescription Revisar en sitio y confirmar diagnostico.',
      urgencia: urgenciaMedia,
      requiereGrua: false,
      recomendacion:
          'Mantente en un lugar seguro y espera la revision inicial del tecnico.',
      confidence: 0.25,
      isFallback: true,
    );
  }

  static EmergencyAiAnalysisModel _fromNewFormat(
    Map<String, dynamic> json, {
    String? fallbackDescription,
  }) {
    final fallback = EmergencyAiAnalysisModel.fallback(fallbackDescription ?? '');
    return EmergencyAiAnalysisModel(
      categoria: _safeEnum(
        json['categoria'],
        allowedCategories,
        fallback: fallback.categoria,
      ),
      tipoDanio: _safeText(json['tipo_danio'], fallback: fallback.tipoDanio),
      resumenTecnico: _safeText(
        json['resumen_tecnico'],
        fallback: fallback.resumenTecnico,
      ),
      urgencia: _safeEnum(
        json['urgencia'],
        allowedUrgencies,
        fallback: fallback.urgencia,
      ),
      requiereGrua: json['requiere_grua'] as bool? ?? fallback.requiereGrua,
      recomendacion: _safeText(
        json['recomendacion'],
        fallback: fallback.recomendacion,
      ),
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0.9)
          .clamp(0, 1)
          .toDouble(),
      isFallback: json['is_fallback'] as bool? ?? fallback.isFallback,
    );
  }

  static EmergencyAiAnalysisModel _fromLegacyFormat(
    Map<String, dynamic> json, {
    String? fallbackDescription,
  }) {
    final fallback = EmergencyAiAnalysisModel.fallback(fallbackDescription ?? '');
    final rawType =
        (json['emergency_type_code'] ?? json['emergency_type'])?.toString();
    final rawPriority = json['priority']?.toString();
    return EmergencyAiAnalysisModel(
      categoria: _legacyTypeToCategory(rawType) ?? fallback.categoria,
      tipoDanio: _safeText(
        json['user_friendly_summary'] ?? json['user_message'],
        fallback: fallback.tipoDanio,
      ),
      resumenTecnico: _safeText(
        json['technician_summary'],
        fallback: fallback.resumenTecnico,
      ),
      urgencia: _legacyPriorityToUrgency(rawPriority) ?? fallback.urgencia,
      requiereGrua:
          (json['requires_immediate_attention'] as bool? ?? false) &&
          _legacyTypeToCategory(rawType) == gruaRemolque,
      recomendacion: _safeText(
        json['safety_recommendation'],
        fallback: fallback.recomendacion,
      ),
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0.5)
          .clamp(0, 1)
          .toDouble(),
      isFallback: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoria': categoria,
      'tipo_danio': tipoDanio,
      'resumen_tecnico': resumenTecnico,
      'urgencia': urgencia,
      'requiere_grua': requiereGrua,
      'recomendacion': recomendacion,
    };
  }

  Map<String, dynamic> toEmergencyInsertJson({required String status}) {
    return {
      'clasificacion_ia': categoria,
      'ai_emergency_type': categoria,
      'ai_priority': urgencia,
      'ai_user_message': tipoDanio,
      'ai_safety_recommendation': recomendacion,
      'ai_technician_summary': resumenTecnico,
      'ai_detected_risks': const <String>[],
      'ai_requires_immediate_attention': requiresImmediateAttention,
      'ai_confidence': confidence,
      'ai_analysis_status': status,
      'ai_analyzed_at': DateTime.now().toIso8601String(),
    };
  }

  bool get isValidEmergency => true;
  String get emergencyType => categoria;
  String get priority => urgencia;
  String get userMessage => tipoDanio;
  String get safetyRecommendation => recomendacion;
  String get technicianSummary => resumenTecnico;
  List<String> get detectedRisks => const <String>[];
  bool get requiresImmediateAttention => urgencia == urgenciaAlta || requiereGrua;

  static bool isAllowedCategory(String? value) => allowedCategories.contains(value);
  static bool isAllowedUrgency(String? value) => allowedUrgencies.contains(value);

  static bool _looksLikeNewFormat(Map<String, dynamic> json) {
    return json.containsKey('categoria') ||
        json.containsKey('tipo_danio') ||
        json.containsKey('resumen_tecnico');
  }

  static String? _legacyTypeToCategory(String? value) {
    return switch (value?.trim()) {
      'minor_mechanic' || 'engine' || 'overheating' || 'brakes' => mecanicaRapida,
      'battery_jumpstart' || 'battery' || 'electrical' => sistemaElectricoBateria,
      'tire_change' || 'flat_tire_no_spare' || 'tire' => llantasVulcanizacion,
      'tow_service' || 'accident' => gruaRemolque,
      'fuel_delivery' || 'fuel' => combustible,
      'locksmith_vehicle' || 'lockout' => cerrajeriaVehicular,
      'unknown' || 'not_emergency' => auxilioGeneral,
      _ => null,
    };
  }

  static String? _legacyPriorityToUrgency(String? value) {
    return switch (value?.trim()) {
      'low' => urgenciaBaja,
      'medium' => urgenciaMedia,
      'high' || 'critical' => urgenciaAlta,
      _ => null,
    };
  }

  static String _safeEnum(
    Object? value,
    Set<String> allowed, {
    required String fallback,
  }) {
    final candidate = value?.toString().trim();
    if (candidate != null && allowed.contains(candidate)) {
      return candidate;
    }
    return fallback;
  }

  static String _safeText(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1).trim()}…';
  }
}
