import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/helpers.dart';
import '../../../map/domain/entities/location_entity.dart';
import '../models/emergency_pricing_model.dart';

class EmergencyPricingService {
  final SupabaseClient _client;

  const EmergencyPricingService(this._client);

  Future<EmergencyPriceQuote> calculateQuote({
    required String emergencyTypeCode,
    required double originLat,
    required double originLng,
    LocationEntity? destination,
  }) async {
    final serviceCode = normalizeEmergencyTypeCode(emergencyTypeCode);
    final tariff = await _fetchActiveTariff(serviceCode);
    if (tariff == null) {
      return _fallbackQuote(serviceCode);
    }

    return switch (tariff.pricingType) {
      'fixed' => _fixedQuote(tariff),
      'range' => _rangeQuote(tariff),
      'diagnostic' => _diagnosticQuote(tariff),
      'distance_based' => _distanceQuote(
          tariff,
          originLat: originLat,
          originLng: originLng,
          destination: destination,
        ),
      _ => _fallbackQuote(serviceCode),
    };
  }

  Future<void> saveSnapshot({
    required String emergencyId,
    required EmergencyPriceQuote quote,
  }) async {
    await _client
        .from(AppConstants.tableEmergencyPriceSnapshots)
        .insert(quote.toSnapshotInsertJson(emergencyId));
  }

  Future<ServiceTariffModel?> _fetchActiveTariff(String serviceCode) async {
    final data = await _client
        .from(AppConstants.tableServiceTariffs)
        .select()
        .eq('code', serviceCode)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return ServiceTariffModel.fromJson(Map<String, dynamic>.from(data));
  }

  EmergencyPriceQuote _fixedQuote(ServiceTariffModel tariff) {
    final total = _money(tariff.basePrice ?? 0);
    return _baseQuote(
      tariff,
      pricingStatus: 'protected',
      estimatedTotal: total,
      protectedTotal: total,
      displayTitle: 'Precio inicial protegido',
      displayMessage: AppHelpers.formatCurrency(total),
      calculationFormula: _moneyText(total),
      calculationBreakdown: {'base_price': total, 'total': total},
      isEstimate: false,
    );
  }

  EmergencyPriceQuote _rangeQuote(ServiceTariffModel tariff) {
    final min = _money(tariff.minPrice ?? 0);
    final max = _money(tariff.maxPrice ?? min);
    return _baseQuote(
      tariff,
      pricingStatus: 'estimated',
      estimatedTotalMin: min,
      estimatedTotalMax: max,
      displayTitle: 'Rango estimado',
      displayMessage:
          '${AppHelpers.formatCurrency(min)} - ${AppHelpers.formatCurrency(max)}',
      calculationFormula: 'range:$min-$max',
      calculationBreakdown: {'min_price': min, 'max_price': max},
      isEstimate: true,
    );
  }

  EmergencyPriceQuote _diagnosticQuote(ServiceTariffModel tariff) {
    final total = _money(tariff.basePrice ?? tariff.minPrice ?? 0);
    return _baseQuote(
      tariff,
      pricingStatus: 'estimated',
      estimatedTotal: total,
      protectedTotal: total > 0 ? total : null,
      displayTitle: 'Tarifa de diagnostico',
      displayMessage:
          '${AppHelpers.formatCurrency(total)}. Costos adicionales requieren aprobacion.',
      calculationFormula: '${_moneyText(total)} diagnostic',
      calculationBreakdown: {'diagnostic_price': total, 'total': total},
      isEstimate: true,
    );
  }

  EmergencyPriceQuote _distanceQuote(
    ServiceTariffModel tariff, {
    required double originLat,
    required double originLng,
    LocationEntity? destination,
  }) {
    final base = _money(tariff.basePrice ?? 0);
    final includedKm = tariff.includedKm ?? 0;
    final pricePerKm = tariff.pricePerKm ?? 0;

    if (destination == null) {
      return _baseQuote(
        tariff,
        pricingStatus: 'pending_destination',
        originLat: originLat,
        originLng: originLng,
        displayTitle: 'Servicio de Grua',
        displayMessage:
            'Desde ${AppHelpers.formatCurrency(base)} + ${AppHelpers.formatCurrency(pricePerKm)}/km adicional',
        calculationFormula:
            '${_moneyText(base)} + max(0, tow_distance_km - ${_kmText(includedKm)}) * ${_moneyText(pricePerKm)}',
        calculationBreakdown: {
          'base_price': base,
          'included_km': includedKm,
          'price_per_km': pricePerKm,
        },
        isEstimate: true,
      );
    }

    final rawDistance = haversineKm(
      originLat,
      originLng,
      destination.lat,
      destination.lng,
    );
    final pricedDistance = _distanceForPricing(rawDistance, tariff.roundingMode);
    final additionalKm = math.max<double>(0, pricedDistance - includedKm);
    final additionalCost = _money(additionalKm * pricePerKm);
    var total = _money(base + additionalCost);
    final minimum = tariff.minimumPrice;
    if (minimum != null && total < minimum) {
      total = _money(minimum);
    }
    final requiresManualReview =
        tariff.maxEstimatedPrice != null && total > tariff.maxEstimatedPrice!;
    final roundedDistance = _distance(rawDistance);

    return _baseQuote(
      tariff,
      pricingStatus:
          requiresManualReview ? 'pending_manual_review' : 'protected',
      originLat: originLat,
      originLng: originLng,
      destinationLat: destination.lat,
      destinationLng: destination.lng,
      towDistanceKm: roundedDistance,
      distanceSource: 'haversine',
      distanceConfidence: 'approximate',
      estimatedTotal: total,
      estimatedTotalMin: total,
      estimatedTotalMax: total,
      protectedTotal: requiresManualReview ? null : total,
      displayTitle: 'Estimado de grua',
      displayMessage: AppHelpers.formatCurrency(total),
      requiresManualReview: requiresManualReview,
      calculationFormula:
          '${_moneyText(base)} + max(0, ${_kmText(pricedDistance)} - ${_kmText(includedKm)}) * ${_moneyText(pricePerKm)}',
      calculationBreakdown: {
        'base_price': base,
        'included_km': includedKm,
        'additional_km': _distance(additionalKm),
        'price_per_km': pricePerKm,
        'additional_distance_cost': additionalCost,
        'minimum_price': tariff.minimumPrice,
        'total': total,
      }..removeWhere((_, value) => value == null),
      isEstimate: true,
    );
  }

  EmergencyPriceQuote _fallbackQuote(String serviceCode) {
    return EmergencyPriceQuote(
      serviceCode: serviceCode,
      serviceName: 'Servicio por revisar',
      pricingType: 'diagnostic',
      pricingStatus: 'pending_manual_review',
      displayTitle: 'Tarifa no disponible',
      displayMessage: 'Se creara la solicitud con revision de diagnostico.',
      requiresDestination: false,
      requiresUserApprovalForExtras: true,
      requiresManualReview: true,
      isEstimate: true,
    );
  }

  EmergencyPriceQuote _baseQuote(
    ServiceTariffModel tariff, {
    required String pricingStatus,
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
    double? towDistanceKm,
    String? distanceSource,
    String? distanceConfidence,
    double? estimatedTotal,
    double? estimatedTotalMin,
    double? estimatedTotalMax,
    double? protectedTotal,
    required String displayTitle,
    required String displayMessage,
    bool requiresManualReview = false,
    String? calculationFormula,
    Map<String, dynamic> calculationBreakdown = const {},
    required bool isEstimate,
  }) {
    return EmergencyPriceQuote(
      serviceCode: tariff.code,
      serviceName: tariff.name,
      pricingType: tariff.pricingType,
      pricingStatus: pricingStatus,
      tariffId: tariff.id,
      tariffVersion: tariff.version,
      basePrice: tariff.basePrice,
      minPrice: tariff.minPrice,
      maxPrice: tariff.maxPrice,
      minimumPrice: tariff.minimumPrice,
      maxEstimatedPrice: tariff.maxEstimatedPrice,
      includedKm: tariff.includedKm,
      pricePerKm: tariff.pricePerKm,
      originLat: originLat,
      originLng: originLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      towDistanceKm: towDistanceKm,
      distanceSource: distanceSource,
      distanceConfidence: distanceConfidence,
      estimatedTotal: estimatedTotal,
      estimatedTotalMin: estimatedTotalMin,
      estimatedTotalMax: estimatedTotalMax,
      protectedTotal: protectedTotal,
      displayTitle: displayTitle,
      displayMessage: displayMessage,
      includesText: tariff.includesText,
      excludesText: tariff.excludesText,
      requiresDestination: tariff.requiresDestination,
      destinationRequiredMessage: tariff.destinationRequiredMessage,
      requiresUserApprovalForExtras: tariff.allowsExtraCharges,
      requiresManualReview: requiresManualReview,
      calculationFormula: calculationFormula,
      calculationBreakdown: calculationBreakdown,
      isEstimate: isEstimate,
    );
  }

  static String serviceCodeFromAnalysis({
    required String? aiType,
    required String description,
    double confidence = 1,
  }) {
    if (confidence < 0.65) return 'unknown';

    final normalized = _normalizeText(description);
    final wantsTow = normalized.contains('grua') ||
        normalized.contains('remol') ||
        normalized.contains('traslad') ||
        normalized.contains('llevar el vehiculo') ||
        normalized.contains('llevar mi vehiculo');
    if (wantsTow) return 'tow_service';

    final type = aiType?.trim();
    if (type == null || type.isEmpty) return 'unknown';
    if (_knownServiceCodes.contains(type)) return type;

    return switch (type) {
      'battery' => 'battery_jumpstart',
      'fuel' => 'fuel_delivery',
      'lockout' => 'locksmith_vehicle',
      'tire' => _tireServiceCode(normalized),
      'engine' ||
      'overheating' ||
      'electrical' ||
      'brakes' ||
      'accident' ||
      'unknown' =>
        'minor_mechanic',
      _ => 'unknown',
    };
  }

  static String normalizeEmergencyTypeCode(String value) {
    if (_knownServiceCodes.contains(value)) return value;
    return serviceCodeFromAnalysis(aiType: value, description: '');
  }

  static String _tireServiceCode(String normalizedDescription) {
    final hasSpare = normalizedDescription.contains('repuesto') ||
        normalizedDescription.contains('llanta de emergencia') ||
        normalizedDescription.contains('tengo llanta') ||
        normalizedDescription.contains('tengo una llanta');
    final noSpare = normalizedDescription.contains('sin repuesto') ||
        normalizedDescription.contains('no tengo repuesto') ||
        normalizedDescription.contains('no tengo llanta');
    if (hasSpare && !noSpare) return 'tire_change';
    return 'flat_tire_no_spare';
  }

  static double haversineKm(
    double originLat,
    double originLng,
    double destinationLat,
    double destinationLng,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(destinationLat - originLat);
    final dLng = _toRadians(destinationLng - originLng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(originLat)) *
            math.cos(_toRadians(destinationLat)) *
            math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _distanceForPricing(double value, String roundingMode) {
    return switch (roundingMode) {
      'ceil' => value.ceilToDouble(),
      'nearest' => value.roundToDouble(),
      _ => value,
    };
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  static double _money(double value) => (value * 100).round() / 100;

  static double _distance(double value) => (value * 100).round() / 100;

  static String _moneyText(double value) => _money(value).toStringAsFixed(2);

  static String _kmText(double value) {
    final rounded = _distance(value);
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(2);
  }

  static String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  static const _knownServiceCodes = {
    'tire_change',
    'flat_tire_no_spare',
    'battery_jumpstart',
    'tow_service',
    'minor_mechanic',
    'locksmith_vehicle',
    'fuel_delivery',
  };
}
