class TechnicianSpecialtyOption {
  final String code;
  final String name;
  final List<String> emergencyTypeCodes;
  final List<String> legacyKeywords;

  const TechnicianSpecialtyOption({
    required this.code,
    required this.name,
    required this.emergencyTypeCodes,
    required this.legacyKeywords,
  });
}

abstract class TechnicianSpecialties {
  static const String mechanicalQuick = 'mechanical_quick';
  static const String batteryElectrical = 'battery_electrical';
  static const String tiresVulcanization = 'tires_vulcanization';
  static const String towTruck = 'tow_truck';
  static const String fuelDelivery = 'fuel_delivery';
  static const String vehicleLocksmith = 'vehicle_locksmith';
  static const String generalAssistance = 'general_assistance';

  static const List<TechnicianSpecialtyOption> options = [
    TechnicianSpecialtyOption(
      code: mechanicalQuick,
      name: 'Mecánica rápida',
      emergencyTypeCodes: [
        'Mecánica rápida',
        'minor_mechanic',
        'engine',
        'overheating',
        'brakes',
      ],
      legacyKeywords: [
        'mecan',
        'motor',
        'freno',
        'radiador',
        'refriger',
      ],
    ),
    TechnicianSpecialtyOption(
      code: batteryElectrical,
      name: 'Sistema eléctrico y batería',
      emergencyTypeCodes: [
        'Sistema eléctrico y batería',
        'battery_jumpstart',
        'battery',
        'electrical',
      ],
      legacyKeywords: [
        'electri',
        'bateria',
        'alternador',
        'arranque',
      ],
    ),
    TechnicianSpecialtyOption(
      code: tiresVulcanization,
      name: 'Llantas y vulcanización',
      emergencyTypeCodes: [
        'Llantas y vulcanización',
        'tire_change',
        'flat_tire_no_spare',
        'tire',
      ],
      legacyKeywords: [
        'llanta',
        'neumatic',
        'vulcan',
        'rueda',
      ],
    ),
    TechnicianSpecialtyOption(
      code: towTruck,
      name: 'Grúa / remolque',
      emergencyTypeCodes: [
        'Grúa / remolque',
        'tow_service',
        'accident',
      ],
      legacyKeywords: [
        'grua',
        'remolque',
        'plataforma',
      ],
    ),
    TechnicianSpecialtyOption(
      code: fuelDelivery,
      name: 'Combustible',
      emergencyTypeCodes: [
        'Combustible',
        'fuel_delivery',
        'fuel',
      ],
      legacyKeywords: [
        'combustible',
        'gasolina',
        'diesel',
      ],
    ),
    TechnicianSpecialtyOption(
      code: vehicleLocksmith,
      name: 'Cerrajería vehicular',
      emergencyTypeCodes: [
        'Cerrajería vehicular',
        'locksmith_vehicle',
        'lockout',
      ],
      legacyKeywords: [
        'cerra',
        'llave',
        'lock',
      ],
    ),
    TechnicianSpecialtyOption(
      code: generalAssistance,
      name: 'Auxilio general',
      emergencyTypeCodes: [
        'Auxilio general',
        'unknown',
        'not_emergency',
      ],
      legacyKeywords: [
        'asistencia',
        'auxilio',
        'general',
      ],
    ),
  ];

  static final Map<String, TechnicianSpecialtyOption> _byCode = {
    for (final option in options) option.code: option,
  };

  static List<String> get codes => options.map((option) => option.code).toList();

  static bool isValidCode(String? value) => _byCode.containsKey(value?.trim());

  static TechnicianSpecialtyOption? byCode(String? value) {
    if (value == null) return null;
    return _byCode[value.trim()];
  }

  static String? normalizeCode(String? rawValue) {
    final trimmed = rawValue?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (isValidCode(trimmed)) return trimmed;

    final normalized = _normalize(trimmed);
    for (final option in options) {
      if (option.legacyKeywords.any(normalized.contains)) {
        return option.code;
      }
    }
    return null;
  }

  static String labelForCode(
    String? value, {
    String fallback = 'Sin especialidad',
  }) {
    final option = byCode(value) ?? byCode(normalizeCode(value));
    if (option != null) return option.name;
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return fallback;
  }

  static List<String> specialtyCodesForEmergencyType(String? emergencyType) {
    final normalizedType = emergencyType?.trim();
    final exactMatches = options
        .where((option) => option.emergencyTypeCodes.contains(normalizedType))
        .map((option) => option.code)
        .toList();
    if (exactMatches.isNotEmpty) return exactMatches;
    return const [generalAssistance];
  }

  static bool matchesEmergencyType({
    required String? specialtyCode,
    required String? emergencyType,
  }) {
    final normalizedSpecialty = normalizeCode(specialtyCode);
    if (normalizedSpecialty == null) return false;
    return specialtyCodesForEmergencyType(emergencyType)
        .contains(normalizedSpecialty);
  }

  static String _normalize(String value) {
    final lower = value.toLowerCase();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }
}
