class EmergencyAiAnalysisModel {
  static const allowedEmergencyTypes = {
    'tire_change',
    'flat_tire_no_spare',
    'battery_jumpstart',
    'tow_service',
    'minor_mechanic',
    'locksmith_vehicle',
    'fuel_delivery',
    'battery',
    'tire',
    'fuel',
    'engine',
    'overheating',
    'accident',
    'lockout',
    'electrical',
    'brakes',
    'unknown',
    'not_emergency',
  };

  static const allowedPriorities = {
    'low',
    'medium',
    'high',
    'critical',
  };

  static const allowedRisks = {
    'vehicle_disabled_in_road',
    'possible_accident',
    'traffic_blockage',
    'severe_visible_damage',
    'smoke',
    'fire',
    'fuel_leak',
    'injury',
    'crash',
    'electrical_risk',
    'brake_failure',
    'severe_overheating',
    'none',
  };

  final bool isValidEmergency;
  final String emergencyType;
  final String priority;
  final String userMessage;
  final String safetyRecommendation;
  final String technicianSummary;
  final List<String> detectedRisks;
  final bool requiresImmediateAttention;
  final double confidence;

  const EmergencyAiAnalysisModel({
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

  factory EmergencyAiAnalysisModel.fromJson(Map<String, dynamic> json) {
    final type = _safeEnum(
      json['emergency_type_code'] ?? json['emergency_type'],
      allowedEmergencyTypes,
      fallback: 'unknown',
    );
    final priority = _safeEnum(
      json['priority'],
      allowedPriorities,
      fallback: 'medium',
    );
    final risks =
        ((json['important_risks'] ?? json['detected_risks']) as List? ??
                const ['none'])
        .map((risk) => _safeEnum(risk, allowedRisks, fallback: 'none'))
        .toSet()
        .toList();

    return EmergencyAiAnalysisModel(
      isValidEmergency: json['is_valid_emergency'] as bool? ?? false,
      emergencyType: type,
      priority: priority,
      userMessage: _safeText(
        json['user_friendly_summary'] ?? json['user_message'],
      ),
      safetyRecommendation: _safeText(json['safety_recommendation']),
      technicianSummary: _safeText(json['technician_summary']),
      detectedRisks: risks.isEmpty ? const ['none'] : risks,
      requiresImmediateAttention:
          json['requires_immediate_attention'] as bool? ?? false,
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0)
          .clamp(0, 1)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_valid_emergency': isValidEmergency,
      'emergency_type_code': emergencyType,
      'priority': priority,
      'user_friendly_summary': userMessage,
      'safety_recommendation': safetyRecommendation,
      'technician_summary': technicianSummary,
      'important_risks': detectedRisks,
      'requires_immediate_attention': requiresImmediateAttention,
      'confidence': confidence,
    };
  }

  Map<String, dynamic> toEmergencyInsertJson({required String status}) {
    return {
      'clasificacion_ia': emergencyType,
      'ai_emergency_type': emergencyType,
      'ai_priority': priority,
      'ai_user_message': userMessage,
      'ai_safety_recommendation': safetyRecommendation,
      'ai_technician_summary': technicianSummary,
      'ai_detected_risks': detectedRisks,
      'ai_requires_immediate_attention': requiresImmediateAttention,
      'ai_confidence': confidence,
      'ai_analysis_status': status,
      'ai_analyzed_at': DateTime.now().toIso8601String(),
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

  static String _safeText(Object? value) {
    return value?.toString().trim() ?? '';
  }
}
