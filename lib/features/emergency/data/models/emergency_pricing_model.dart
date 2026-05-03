import '../../../../core/utils/helpers.dart';

class ServiceTariffModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String pricingType;
  final double? basePrice;
  final double? minPrice;
  final double? maxPrice;
  final double? minimumPrice;
  final double? maxEstimatedPrice;
  final double? includedKm;
  final double? pricePerKm;
  final String distanceUnit;
  final String roundingMode;
  final bool requiresDestination;
  final String? destinationRequiredMessage;
  final String? includesText;
  final String? excludesText;
  final bool requiresDiagnostic;
  final bool allowsExtraCharges;
  final bool isActive;
  final int sortOrder;
  final int version;

  const ServiceTariffModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.pricingType,
    this.basePrice,
    this.minPrice,
    this.maxPrice,
    this.minimumPrice,
    this.maxEstimatedPrice,
    this.includedKm,
    this.pricePerKm,
    required this.distanceUnit,
    required this.roundingMode,
    required this.requiresDestination,
    this.destinationRequiredMessage,
    this.includesText,
    this.excludesText,
    required this.requiresDiagnostic,
    required this.allowsExtraCharges,
    required this.isActive,
    required this.sortOrder,
    required this.version,
  });

  factory ServiceTariffModel.fromJson(Map<String, dynamic> json) {
    return ServiceTariffModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      pricingType: json['pricing_type'] as String,
      basePrice: (json['base_price'] as num?)?.toDouble(),
      minPrice: (json['min_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      minimumPrice: (json['minimum_price'] as num?)?.toDouble(),
      maxEstimatedPrice: (json['max_estimated_price'] as num?)?.toDouble(),
      includedKm: (json['included_km'] as num?)?.toDouble(),
      pricePerKm: (json['price_per_km'] as num?)?.toDouble(),
      distanceUnit: json['distance_unit'] as String? ?? 'km',
      roundingMode: json['rounding_mode'] as String? ?? 'exact',
      requiresDestination: json['requires_destination'] as bool? ?? false,
      destinationRequiredMessage:
          json['destination_required_message'] as String?,
      includesText: json['includes_text'] as String?,
      excludesText: json['excludes_text'] as String?,
      requiresDiagnostic: json['requires_diagnostic'] as bool? ?? false,
      allowsExtraCharges: json['allows_extra_charges'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}

class EmergencyPriceQuote {
  final String serviceCode;
  final String serviceName;
  final String pricingType;
  final String pricingStatus;
  final String currency;
  final String? tariffId;
  final int? tariffVersion;
  final double? basePrice;
  final double? minPrice;
  final double? maxPrice;
  final double? minimumPrice;
  final double? maxEstimatedPrice;
  final double? includedKm;
  final double? pricePerKm;
  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? towDistanceKm;
  final double? approachDistanceKm;
  final String? distanceSource;
  final String? distanceConfidence;
  final double? estimatedTotal;
  final double? estimatedTotalMin;
  final double? estimatedTotalMax;
  final double? protectedTotal;
  final double? finalTotal;
  final String displayTitle;
  final String displayMessage;
  final String? includesText;
  final String? excludesText;
  final bool requiresDestination;
  final String? destinationRequiredMessage;
  final bool requiresUserApprovalForExtras;
  final bool requiresManualReview;
  final String? calculationFormula;
  final Map<String, dynamic> calculationBreakdown;
  final bool isEstimate;

  const EmergencyPriceQuote({
    required this.serviceCode,
    required this.serviceName,
    required this.pricingType,
    required this.pricingStatus,
    this.currency = 'USD',
    this.tariffId,
    this.tariffVersion,
    this.basePrice,
    this.minPrice,
    this.maxPrice,
    this.minimumPrice,
    this.maxEstimatedPrice,
    this.includedKm,
    this.pricePerKm,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.towDistanceKm,
    this.approachDistanceKm,
    this.distanceSource,
    this.distanceConfidence,
    this.estimatedTotal,
    this.estimatedTotalMin,
    this.estimatedTotalMax,
    this.protectedTotal,
    this.finalTotal,
    required this.displayTitle,
    required this.displayMessage,
    this.includesText,
    this.excludesText,
    required this.requiresDestination,
    this.destinationRequiredMessage,
    this.requiresUserApprovalForExtras = true,
    this.requiresManualReview = false,
    this.calculationFormula,
    this.calculationBreakdown = const {},
    this.isEstimate = true,
  });

  bool get canCreateEmergency =>
      pricingStatus != 'pending_destination';

  String? get protectedAmountLabel =>
      protectedTotal == null ? null : AppHelpers.formatCurrency(protectedTotal!);

  Map<String, dynamic> toSnapshotJson() {
    return {
      'pricing_type': pricingType,
      'pricing_status': pricingStatus,
      'service_code': serviceCode,
      'service_name': serviceName,
      'tariff_id': tariffId,
      'tariff_version': tariffVersion,
      'currency': currency,
      'base_price': basePrice,
      'min_price': minPrice,
      'max_price': maxPrice,
      'minimum_price': minimumPrice,
      'max_estimated_price': maxEstimatedPrice,
      'included_km': includedKm,
      'price_per_km': pricePerKm,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'tow_distance_km': towDistanceKm,
      'approach_distance_km': approachDistanceKm,
      'distance_source': distanceSource,
      'distance_confidence': distanceConfidence,
      'estimated_total': estimatedTotal,
      'estimated_total_min': estimatedTotalMin,
      'estimated_total_max': estimatedTotalMax,
      'protected_total': protectedTotal,
      'final_total': finalTotal,
      'display_title': displayTitle,
      'display_message': displayMessage,
      'calculation_formula': calculationFormula,
      'calculation_breakdown': calculationBreakdown,
      'includes_text': includesText,
      'excludes_text': excludesText,
      'requires_user_approval_for_extras': requiresUserApprovalForExtras,
      'requires_destination': requiresDestination,
      'destination_required_message': destinationRequiredMessage,
      'is_estimate': isEstimate,
      'requires_manual_review': requiresManualReview,
    }..removeWhere((_, value) => value == null);
  }

  Map<String, dynamic> toSnapshotInsertJson(String emergencyId) {
    return {
      'emergency_id': emergencyId,
      if (tariffId != null) 'tariff_id': tariffId,
      'snapshot': toSnapshotJson(),
      'pricing_type': pricingType,
      'pricing_status': pricingStatus,
      'service_code': serviceCode,
      'currency': currency,
      if (estimatedTotal != null) 'estimated_total': estimatedTotal,
      if (protectedTotal != null) 'protected_total': protectedTotal,
      if (finalTotal != null) 'final_total': finalTotal,
      'requires_manual_review': requiresManualReview,
    };
  }
}
