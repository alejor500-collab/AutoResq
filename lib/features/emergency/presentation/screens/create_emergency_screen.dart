import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/emergency_match_policy.dart';
import '../../../../core/constants/payment_methods.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/utils/app_responsive.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../map/domain/entities/location_entity.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../map/presentation/widgets/location_picker_sheet.dart';
import '../../data/models/emergency_ai_analysis_model.dart';
import '../../data/models/emergency_pricing_model.dart';
import '../../data/services/emergency_pricing_service.dart';
import '../providers/emergency_provider.dart';
import '../../domain/entities/emergency_entity.dart';

class CreateEmergencyScreen extends ConsumerStatefulWidget {
  const CreateEmergencyScreen({super.key});

  @override
  ConsumerState<CreateEmergencyScreen> createState() =>
      _CreateEmergencyScreenState();
}

class _CreateEmergencyScreenState extends ConsumerState<CreateEmergencyScreen> {
  final _descCtrl = TextEditingController();
  static const int _minDescriptionLength = 8;
  static const int _maxDescriptionLength = 1800;
  int _currentStep = 0;
  EmergencyAiAnalysisModel? _aiResult;
  EmergencyPriceQuote? _pricingQuote;
  LocationEntity? _destinationLocation;
  final List<XFile> _attachments = [];
  List<String> _evidencePhotoUrls = const [];
  bool _aiAnalysisAttempted = false;
  bool _isPricingLoading = false;
  bool _isUploadingEvidence = false;
  String _paymentMethod = PaymentMethods.cash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(mapNotifierProvider).currentLocation == null) {
        ref.read(mapNotifierProvider.notifier).getCurrentLocation();
      }
    });
    final user = ref.read(authNotifierProvider).valueOrNull;
    _paymentMethod = PaymentMethods.normalize(user?.preferredPaymentMethod);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  String? _validateEmergencyDescription(String rawValue) {
    final normalized = _normalizedEmergencyDescription(rawValue);
    if (normalized.isEmpty) {
      return 'Cuéntanos qué está pasando con tu vehículo para poder pedir ayuda.';
    }
    if (normalized.length < _minDescriptionLength) {
      return 'Agrega un poco más de detalle. Por ejemplo: “se apagó en la vía”, “necesito grúa” o “no enciende”.';
    }
    if (normalized.length > _maxDescriptionLength) {
      return 'La descripción es muy larga. Resume lo más importante en menos de $_maxDescriptionLength caracteres.';
    }
    final meaningfulChars = normalized.replaceAll(
      RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ]'),
      '',
    );
    if (meaningfulChars.length < _minDescriptionLength) {
      return 'Escribe el problema con palabras. La IA puede interpretar tu descripción aunque sea breve.';
    }
    if (RegExp(r'(.)\1{7,}', unicode: true).hasMatch(meaningfulChars)) {
      return 'Parece que hay caracteres repetidos. Escribe una frase corta sobre lo que ocurre.';
    }
    return null;
  }

  String _normalizedEmergencyDescription(String rawValue) {
    return rawValue
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _showInvalidDescriptionDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Completa la descripción'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _analyzeAI() async {
    final description = _normalizedEmergencyDescription(_descCtrl.text);
    final validationMessage = _validateEmergencyDescription(description);
    if (validationMessage != null) {
      await _showInvalidDescriptionDialog(validationMessage);
      return;
    }
    final evidenceUrls = await _ensureEvidenceUploaded();
    if (!mounted || evidenceUrls == null) return;
    final mapState = ref.read(mapNotifierProvider);
    final result =
        await ref.read(emergencyNotifierProvider.notifier).analyzeWithAI(
              description,
              lat: mapState.currentLocation?.lat,
              lng: mapState.currentLocation?.lng,
              address: mapState.currentLocation?.address,
              evidencePhotoUrls: evidenceUrls,
            );
    if (!mounted) return;
    setState(() {
      _aiResult = result;
      _aiAnalysisAttempted = true;
      _currentStep = 2;
    });
    await _calculatePricingQuote();
  }

  Future<void> _calculatePricingQuote() async {
    final mapState = ref.read(mapNotifierProvider);
    final lat = mapState.currentLocation?.lat ?? AppConstants.defaultLat;
    final lng = mapState.currentLocation?.lng ?? AppConstants.defaultLng;
    final serviceCode = EmergencyPricingService.serviceCodeFromAnalysis(
      aiType: _aiResult?.emergencyType,
      description: _normalizedEmergencyDescription(_descCtrl.text),
      confidence: _aiResult?.confidence ?? 0,
    );

    setState(() => _isPricingLoading = true);
    try {
      final quote =
          await ref.read(emergencyPricingServiceProvider).calculateQuote(
                emergencyTypeCode: serviceCode,
                originLat: lat,
                originLng: lng,
                destination: _destinationLocation,
              );
      if (!mounted) return;
      setState(() {
        _pricingQuote = quote;
        _isPricingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pricingQuote = const EmergencyPriceQuote(
          serviceCode: 'unknown',
          serviceName: 'Servicio por revisar',
          pricingType: 'diagnostic',
          pricingStatus: 'pending_manual_review',
          displayTitle: 'Tarifa no disponible',
          displayMessage: 'Se creará la solicitud con revisión de diagnóstico.',
          requiresDestination: false,
          requiresManualReview: true,
        );
        _isPricingLoading = false;
      });
    }
  }

  Future<void> _selectTowDestination() async {
    final selected = await showLocationPickerSheet(
      context,
      title: 'Seleccionar destino de traslado',
      initialLocation: _destinationLocation,
    );
    if (selected == null || !mounted) return;
    setState(() => _destinationLocation = selected);
    await _calculatePricingQuote();
  }

  Future<void> _createEmergency() async {
    final description = _normalizedEmergencyDescription(_descCtrl.text);
    final validationMessage = _validateEmergencyDescription(description);
    if (validationMessage != null) {
      await _showInvalidDescriptionDialog(validationMessage);
      return;
    }

    Map<String, dynamic>? pendingRating;
    try {
      pendingRating = await ref
          .read(emergencyNotifierProvider.notifier)
          .getPendingRating('driver');
    } catch (_) {
      pendingRating = null;
    }
    if (pendingRating != null) {
      if (!mounted) return;
      _showPendingRatingDialog(pendingRating);
      return;
    }

    final active = await ref
        .read(emergencyNotifierProvider.notifier)
        .loadActiveDriverEmergency();
    if (!mounted) return;
    if (active != null) {
      AppHelpers.showSnackBar(
        context,
        'Ya tienes una emergencia activa.',
        isError: true,
      );
      context.pushReplacement(AppRoutes.emergencyStatus, extra: active.id);
      return;
    }

    if (_pricingQuote == null) {
      await _calculatePricingQuote();
    }
    if (!mounted) return;
    final quote = _pricingQuote;
    if (quote?.pricingStatus == 'pending_destination') {
      AppHelpers.showSnackBar(
        context,
        quote?.destinationRequiredMessage ??
            'Selecciona el destino de traslado para continuar.',
        isError: true,
      );
      await _selectTowDestination();
      return;
    }

    final mapState = ref.read(mapNotifierProvider);
    final lat = mapState.currentLocation?.lat ?? AppConstants.defaultLat;
    final lng = mapState.currentLocation?.lng ?? AppConstants.defaultLng;
    final address = mapState.currentLocation?.address;
    final evidenceUrls = await _ensureEvidenceUploaded();
    if (!mounted || evidenceUrls == null) return;

    AiAnalysis? aiAnalysis;
    if (_aiResult != null) {
      aiAnalysis = AiAnalysis(
        categoria: _aiResult!.categoria,
        tipoDanio: _aiResult!.tipoDanio,
        resumenTecnico: _aiResult!.resumenTecnico,
        urgencia: _aiResult!.urgencia,
        requiereGrua: _aiResult!.requiereGrua,
        recomendacion: _aiResult!.recomendacion,
        confidence: _aiResult!.confidence,
      );
    }

    final emergency =
        await ref.read(emergencyNotifierProvider.notifier).createEmergency(
              description: description,
              lat: lat,
              lng: lng,
              address: address,
              aiAnalysis: aiAnalysis,
              skipAiAnalysis: _aiAnalysisAttempted && aiAnalysis == null,
              priceQuote: quote,
              paymentMethod: _paymentMethod,
              evidencePhotos: _attachments,
              evidencePhotoUrls: evidenceUrls,
            );

    if (!mounted) return;

    if (emergency != null) {
      context.pushReplacement(AppRoutes.emergencyStatus, extra: emergency.id);
    } else {
      final error = ref.read(emergencyNotifierProvider).error;
      AppHelpers.showSnackBar(
        context,
        error ?? 'No se pudo crear la emergencia. Intenta nuevamente.',
        isError: true,
      );
    }
  }

  Future<List<String>?> _ensureEvidenceUploaded() async {
    if (_attachments.isEmpty) return const [];
    if (_evidencePhotoUrls.length == _attachments.length) {
      return _evidencePhotoUrls;
    }

    setState(() => _isUploadingEvidence = true);
    try {
      final urls = await ref
          .read(emergencyNotifierProvider.notifier)
          .uploadEvidencePhotos(_attachments);
      if (!mounted) return null;
      if (urls.length != _attachments.length) {
        AppHelpers.showSnackBar(
          context,
          'No se pudieron subir todas las fotos. Intenta nuevamente o elimina las fotos para continuar.',
          isError: true,
        );
        return null;
      }
      setState(() => _evidencePhotoUrls = urls);
      return urls;
    } catch (_) {
      if (!mounted) return null;
      AppHelpers.showSnackBar(
        context,
        'No se pudieron subir las fotos. Revisa tu conexion e intenta nuevamente.',
        isError: true,
      );
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingEvidence = false);
    }
  }

  Future<void> _editEmergencyLocation() async {
    final selected = await showLocationPickerSheet(
      context,
      title: 'Editar ubicacion de emergencia',
      initialLocation: ref.read(mapNotifierProvider).currentLocation,
    );
    if (selected == null || !mounted) return;
    ref.read(mapNotifierProvider.notifier).setLocation(selected);
    if (_currentStep == 2) {
      await _calculatePricingQuote();
    }
  }

  void _showPendingRatingDialog(Map<String, dynamic> pendingRating) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Tienes una calificacion pendiente'),
          content: const Text(
            'Califica tu ultimo servicio para poder solicitar una nueva emergencia.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.push(
                  AppRoutes.rateService,
                  extra: {
                    'emergencyId':
                        pendingRating['emergency_id']?.toString() ?? '',
                    'technicianId':
                        pendingRating['rated_user_id']?.toString() ?? '',
                    'technicianName':
                        pendingRating['rated_user_name']?.toString() ??
                            'Tecnico',
                  },
                );
              },
              child: const Text('Calificar ahora'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyNotifierProvider);
    final mapState = ref.watch(mapNotifierProvider);
    final horizontal = AppResponsive.horizontalPadding(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.pageBackgroundGradient,
              ),
            ),
          ),
          // Glass AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 64 + MediaQuery.of(context).padding.top,
                  padding:
                      EdgeInsets.only(top: topInset),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withValues(alpha: 0.06),
                        blurRadius: 40,
                        offset: const Offset(0, 40),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (_currentStep > 0) {
                                setState(() => _currentStep--);
                              } else {
                                context.pop();
                              }
                            },
                            icon: Icon(
                              _currentStep > 0
                                  ? Icons.arrow_back
                                  : Icons.close,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        const Gap(8),
                        const Expanded(
                          child: Center(
                            child: AppLogo(height: 28, width: 118),
                          ),
                        ),
                        const Gap(8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.help_outline,
                              size: 16, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            top: 64 + topInset,
            bottom: 0,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 120),
              child: AppResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Progress Indicator
                  _StepProgress(currentStep: _currentStep),
                  const Gap(16),

                  if (_currentStep != 2) ...[
                    Text(
                      _stepTitle,
                      style: TextStyle(
                        fontSize: AppResponsive.titleSize(context),
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: 0,
                        height: 1.2,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      _stepSubtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.secondary,
                        height: 1.5,
                      ),
                    ),
                    const Gap(24),
                  ] else
                    const Gap(18),

                  // Step Content
                  AppStepSwitcher(
                    value: _currentStep,
                    child: switch (_currentStep) {
                      0 => _LocationStep(
                          mapState: mapState,
                          onEdit: _editEmergencyLocation,
                        ),
                      1 => _DescriptionStep(
                          controller: _descCtrl,
                          isAnalyzing: emergencyState.isAnalyzingAI,
                          attachments: _attachments,
                          onAttachmentsChanged: (photos) {
                            setState(() {
                              _attachments
                                ..clear()
                                ..addAll(photos);
                              _evidencePhotoUrls = const [];
                              if (_currentStep < 2) {
                                _aiResult = null;
                                _aiAnalysisAttempted = false;
                              }
                            });
                          },
                        ),
                      2 => _DiagnosticStep(
                          result: _aiResult,
                          pricingQuote: _pricingQuote,
                          isPricingLoading: _isPricingLoading,
                          origin: mapState.currentLocation,
                          destination: _destinationLocation,
                          onSelectDestination: _selectTowDestination,
                          paymentMethod: _paymentMethod,
                          onPaymentMethodChanged: (value) {
                            setState(
                              () => _paymentMethod =
                                  PaymentMethods.normalize(value),
                            );
                          },
                        ),
                      _ => const SizedBox.shrink(),
                    },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(40)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    18,
                    horizontal,
                    MediaQuery.of(context).padding.bottom + 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withValues(alpha: 0.04),
                        blurRadius: 40,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: AppResponsiveContent(
                    maxWidth: AppResponsive.actionMaxWidth(context),
                    child: _buildBottomButton(emergencyState),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'Paso 1: Ubicacion';
      case 1:
        return 'Paso 2: \u00bfQue sucede?';
      case 2:
        return 'Paso 3: Diagnóstico preliminar';
      default:
        return '';
    }
  }

  String get _stepSubtitle {
    switch (_currentStep) {
      case 0:
        return 'Confirma donde necesitas la asistencia tecnica.';
      case 1:
        return 'Escribe con tus palabras. La IA lo interpretará para el técnico.';
      case 2:
        return 'Resultado del análisis inteligente.';
      default:
        return '';
    }
  }

  Widget _buildBottomButton(dynamic emergencyState) {
    switch (_currentStep) {
      case 0:
        return _GradientActionButton(
          label: 'Continuar',
          icon: Icons.arrow_forward,
          onPressed: () => setState(() => _currentStep = 1),
        );
      case 1:
        return _GradientActionButton(
          label: _isUploadingEvidence
              ? 'Subiendo fotos...'
              : emergencyState.isAnalyzingAI
              ? 'Analizando...'
              : 'Analizar con IA',
          icon: Icons.psychology,
          isLoading: emergencyState.isAnalyzingAI || _isUploadingEvidence,
          onPressed: emergencyState.isAnalyzingAI || _isUploadingEvidence
              ? null
              : _analyzeAI,
        );
      case 2:
        final needsDestination =
            _pricingQuote?.pricingStatus == 'pending_destination';
        return _GradientActionButton(
          label: _isUploadingEvidence
              ? 'Subiendo fotos...'
              : _isPricingLoading
              ? 'Calculando tarifa...'
              : emergencyState.isLoading
                  ? 'Enviando...'
                  : needsDestination
                      ? 'Seleccionar destino'
                      : 'Publicar solicitud',
          icon: needsDestination ? Icons.map_outlined : Icons.arrow_forward,
          isEmergency: !needsDestination,
          isLoading:
              emergencyState.isLoading || _isPricingLoading || _isUploadingEvidence,
          onPressed: emergencyState.isLoading ||
                  _isPricingLoading ||
                  _isUploadingEvidence
              ? null
              : needsDestination
                  ? _selectTowDestination
                  : _createEmergency,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// â”€â”€â”€ Step Progress Indicator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StepProgress extends StatelessWidget {
  final int currentStep;

  const _StepProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            curve: Curves.easeOutCubic,
            height: 6,
            margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
            decoration: BoxDecoration(
              color: i <= currentStep
                  ? AppColors.primary
                  : AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

// â”€â”€â”€ Step 1: Location â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _LocationStep extends StatelessWidget {
  final dynamic mapState;
  final VoidCallback onEdit;

  const _LocationStep({
    required this.mapState,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final lat = mapState.currentLocation?.lat ?? AppConstants.defaultLat;
    final lng = mapState.currentLocation?.lng ?? AppConstants.defaultLng;
    final hasPreciseLocation = mapState.currentLocation != null;
    final displayAddress = mapState.isLoading
        ? 'Obteniendo ubicacion...'
        : mapState.currentLocation?.address ??
            mapState.error ??
            'Ubicacion por confirmar';
    final coordinatesLabel = hasPreciseLocation
        ? 'Coordenadas exactas: ${DioClient.formatCoordinates(lat, lng)}'
        : 'Selecciona o confirma tu ubicacion exacta en el mapa';
    final helperLabel = mapState.error != null && hasPreciseLocation
        ? mapState.error
        : coordinatesLabel;
    final hasLocationWarning = mapState.error != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Map
          SizedBox(
            height: AppResponsive.mapHeight(
              context,
              compact: 180,
              regular: 220,
              tablet: 260,
            ),
            child: Stack(
              children: [
                FlutterMap(
                  key: ValueKey('$lat,$lng'),
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: AppConstants.osmTileUrl,
                      userAgentPackageName: 'com.autoresq.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.my_location,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2)
                        ],
                      ),
                    ),
                  ),
                ),
                // Live detection badge
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: hasPreciseLocation
                          ? AppColors.primary
                          : AppColors.warning,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasPreciseLocation
                              ? Icons.my_location
                              : Icons.location_searching_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        const Gap(6),
                        Flexible(
                          child: Text(
                            hasPreciseLocation
                                ? 'UBICACION DETECTADA'
                                : 'CONFIRMA TU UBICACION',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),
          // Address info
          Padding(
            padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIRECCION ACTUAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.secondary,
                  ),
                ),
                const Gap(6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        displayAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const Gap(8),
                    TextButton(
                      onPressed: onEdit,
                      child: const Text(
                        'EDITAR',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  helperLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        hasLocationWarning ? FontWeight.w700 : FontWeight.w500,
                    height: 1.35,
                    color:
                        hasLocationWarning ? AppColors.error : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Step 2: Description â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DescriptionStep extends StatefulWidget {
  final TextEditingController controller;
  final bool isAnalyzing;
  final List<XFile> attachments;
  final ValueChanged<List<XFile>> onAttachmentsChanged;

  const _DescriptionStep({
    required this.controller,
    required this.isAnalyzing,
    required this.attachments,
    required this.onAttachmentsChanged,
  });

  @override
  State<_DescriptionStep> createState() => _DescriptionStepState();
}

class _DescriptionStepState extends State<_DescriptionStep> {
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null || !mounted) return;
      if (widget.attachments.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Puedes adjuntar hasta 3 fotos por solicitud'),
          ),
        );
        return;
      }
      widget.onAttachmentsChanged([...widget.attachments, image]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Foto capturada'
                : 'Foto agregada',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'No se pudo abrir la camara'
                : 'No se pudo seleccionar la foto',
          ),
        ),
      );
    }
  }

  void _removeImage(int index) {
    final updated = [...widget.attachments]..removeAt(index);
    widget.onAttachmentsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI analyzing badge
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology, size: 14, color: AppColors.primary),
                Gap(6),
                Flexible(
                  child: Text(
                    'IA analizando tipo de falla...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(16),

        // Description field
        Container(
          padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.75),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CUÉNTANOS QUÉ PASÓ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Gap(6),
              const Text(
                'Puedes escribir libremente: síntomas, ruido, ubicación, si necesitas grúa o cualquier detalle útil. No tienes que elegir palabras exactas.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Gap(12),
              TextField(
                controller: widget.controller,
                minLines: 5,
                maxLines: 6,
                maxLength: _CreateEmergencyScreenState._maxDescriptionLength,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.onSurface,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Ej: Se apagó en la vía y no vuelve a encender. Estoy a un lado de la carretera.',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: AppColors.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const Gap(16),
              // Action chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionChip(
                    icon: Icons.photo_camera_outlined,
                    label: 'Tomar foto',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  _ActionChip(
                    icon: Icons.upload_file_outlined,
                    label: 'Subir foto',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
              if (widget.attachments.isNotEmpty) ...[
                const Gap(12),
                _SelectedPhotoStrip(
                  photos: widget.attachments,
                  onRemove: _removeImage,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedPhotoStrip extends StatelessWidget {
  final List<XFile> photos;
  final ValueChanged<int> onRemove;

  const _SelectedPhotoStrip({
    required this.photos,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 18,
                color: AppColors.primary,
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  '${photos.length} foto${photos.length == 1 ? '' : 's'} agregada${photos.length == 1 ? '' : 's'} para el analisis y el tecnico',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const Gap(10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const Gap(8),
              itemBuilder: (context, index) {
                return _SelectedPhotoThumb(
                  photo: photos[index],
                  onRemove: () => onRemove(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPhotoThumb extends StatelessWidget {
  final XFile photo;
  final VoidCallback onRemove;

  const _SelectedPhotoThumb({
    required this.photo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<Uint8List>(
            future: photo.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  width: 72,
                  height: 72,
                  color: AppColors.surfaceContainerHigh,
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return Image.memory(
                snapshot.data!,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: AppColors.error,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.onSurface),
            const Gap(8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ Step 3: AI Diagnostic â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DiagnosticStep extends StatelessWidget {
  final EmergencyAiAnalysisModel? result;
  final EmergencyPriceQuote? pricingQuote;
  final bool isPricingLoading;
  final LocationEntity? origin;
  final LocationEntity? destination;
  final VoidCallback onSelectDestination;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;

  const _DiagnosticStep({
    required this.result,
    required this.pricingQuote,
    required this.isPricingLoading,
    required this.origin,
    required this.destination,
    required this.onSelectDestination,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final analysis = result;
    final categoria = analysis?.categoria ?? 'Auxilio general';
    final urgencia = analysis?.urgencia ?? 'media';
    final tipoDanio = analysis?.tipoDanio ??
        'Crearemos la emergencia con tu descripcion original.';
    final resumenTecnico = analysis?.resumenTecnico ?? '';
    final recomendacion = analysis?.recomendacion ?? '';
    final requiereGrua = analysis?.requiereGrua ?? false;
    final failed = analysis == null;
    final categoryForeground = _categoryForeground(categoria);
    final categoryIcon = _categoryIcon(categoria);
    final confidencePercent =
        ((analysis?.confidence ?? 0.25) * 100).round().clamp(1, 99);
    final categoryBandText = EmergencyMatchPolicy.isTowCategory(categoria)
        ? 'Radio inicial sugerido: 10 km'
        : 'Radio inicial sugerido: 5 km';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                failed ? 'Diagnóstico no disponible' : 'Diagnóstico generado',
                style: TextStyle(
                  fontSize: AppResponsive.titleSize(context) + 4,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                  height: 1.05,
                ),
              ),
              const Gap(8),
              Text(
                failed
                    ? 'Usaremos tu descripción original para publicar la solicitud.'
                    : 'La IA organizó la información para ayudarte a solicitar la asistencia correcta.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.secondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const Gap(18),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.05),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.04),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: failed
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _AnalysisHeroHeader(
                            icon: Icons.psychology_alt_rounded,
                            title: 'Diagnóstico por confirmar',
                            subtitle:
                                'La solicitud continuará con revisión técnica en sitio.',
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AnalysisHeroHeader(
                            icon: categoryIcon,
                            title: categoria,
                            subtitle: categoryBandText,
                            iconBackground: categoryForeground,
                          ),
                          const Gap(14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _AnalysisScoreBadge(
                                label: 'Confianza IA',
                                value: '$confidencePercent%',
                                color: AppColors.primary,
                              ),
                              _AnalysisPill(
                                icon: Icons.flag_outlined,
                                label: _urgencyLabel(urgencia),
                                foreground: _urgencyForeground(urgencia),
                                background: _urgencyBackground(urgencia),
                              ),
                              _AnalysisPill(
                                icon: requiereGrua
                                    ? Icons.local_shipping_outlined
                                    : Icons.directions_car_outlined,
                                label: requiereGrua
                                    ? 'Requiere grúa'
                                    : 'Sin grúa inicial',
                                foreground: AppColors.onSurface,
                                background: AppColors.surfaceContainerLow,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    if (!failed) ...[
                      const Gap(18),
                      _AnalysisDetailRow(
                        icon: Icons.warning_amber_rounded,
                        title: 'Posible problema',
                        body: tipoDanio,
                      ),
                      if (resumenTecnico.isNotEmpty)
                        _AnalysisDetailRow(
                          icon: Icons.handyman_outlined,
                          title: 'Resumen técnico',
                          body: resumenTecnico,
                        ),
                      if (recomendacion.isNotEmpty)
                        _AnalysisDetailRow(
                          icon: Icons.lightbulb_outline_rounded,
                          title: 'Recomendación inicial',
                          body: recomendacion,
                        ),
                    ] else ...[
                      const Gap(18),
                      const _AnalysisDetailRow(
                        icon: Icons.info_outline_rounded,
                        title: 'Continuaremos con tu solicitud',
                        body:
                            'Usaremos tu descripción original y un técnico validará el caso cuando llegue al sitio.',
                        showDivider: false,
                      ),
                    ],
                    const _AnalysisDetailRow(
                      icon: Icons.timer_outlined,
                      title: 'Tiempo estimado',
                      body: '15 a 20 min',
                    ),
                    _AnalysisDetailRow(
                      icon: Icons.payments_outlined,
                      title: 'Rango referencial',
                      body: pricingQuote?.displayMessage ??
                          'Te mostraremos la tarifa estimada antes de publicar la solicitud.',
                      showDivider: false,
                    ),
                    const Gap(8),
                    Text(
                      'Cualquier reparación, repuesto o costo adicional deberá aprobarse contigo antes de continuar.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.secondary.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(14),
        _PricingCard(
          quote: pricingQuote,
          isLoading: isPricingLoading,
          destination: destination,
          onSelectDestination: onSelectDestination,
        ),
        if (pricingQuote?.pricingType == 'distance_based' ||
            EmergencyMatchPolicy.isTowCategory(categoria)) ...[
          const Gap(14),
          _TowRoutePreview(
            origin: origin,
            destination: destination,
            onSelectDestination: onSelectDestination,
          ),
        ],
        const Gap(14),
        _PaymentMethodCard(
          selected: paymentMethod,
          onChanged: onPaymentMethodChanged,
        ),
      ],
    );
  }
}

class _AnalysisHeroHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconBackground;

  const _AnalysisHeroHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: iconBackground ?? AppColors.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (iconBackground ?? AppColors.primary)
                    .withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const Gap(14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                  height: 1.1,
                ),
              ),
              const Gap(6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalysisScoreBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalysisScoreBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool showDivider;

  const _AnalysisDetailRow({
    required this.icon,
    required this.title,
    required this.body,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showDivider) ...[
            const Gap(14),
            Divider(
              height: 1,
              color: AppColors.outlineVariant.withValues(alpha: 0.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  const _AnalysisPill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const Gap(6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

String _urgencyLabel(String urgencia) {
  return switch (urgencia) {
    'alta' => 'Urgencia alta',
    'baja' => 'Urgencia baja',
    _ => 'Urgencia media',
  };
}

Color _urgencyForeground(String urgencia) {
  return switch (urgencia) {
    'alta' => const Color(0xFF9F2D20),
    'baja' => const Color(0xFF246B45),
    _ => const Color(0xFF8A5A12),
  };
}

Color _urgencyBackground(String urgencia) {
  return switch (urgencia) {
    'alta' => const Color(0xFFFDE8E4),
    'baja' => const Color(0xFFEAF7EF),
    _ => const Color(0xFFFFF2DE),
  };
}

IconData _categoryIcon(String categoria) {
  return switch (categoria) {
    EmergencyAiAnalysisModel.mecanicaRapida => Icons.build_circle_outlined,
    EmergencyAiAnalysisModel.sistemaElectricoBateria =>
      Icons.battery_charging_full_rounded,
    EmergencyAiAnalysisModel.llantasVulcanizacion => Icons.tire_repair_rounded,
    EmergencyAiAnalysisModel.gruaRemolque => Icons.local_shipping_outlined,
    EmergencyAiAnalysisModel.combustible => Icons.local_gas_station_outlined,
    EmergencyAiAnalysisModel.cerrajeriaVehicular => Icons.key_outlined,
    _ => Icons.support_agent_rounded,
  };
}

Color _categoryForeground(String categoria) {
  return switch (categoria) {
    EmergencyAiAnalysisModel.mecanicaRapida => AppColors.primary,
    EmergencyAiAnalysisModel.sistemaElectricoBateria => AppColors.warning,
    EmergencyAiAnalysisModel.llantasVulcanizacion => AppColors.tertiary,
    EmergencyAiAnalysisModel.gruaRemolque => AppColors.emergency,
    EmergencyAiAnalysisModel.combustible => AppColors.success,
    EmergencyAiAnalysisModel.cerrajeriaVehicular => AppColors.secondary,
    _ => AppColors.primary,
  };
}

class _PaymentMethodCard extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PaymentMethodCard({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FORMA DE PAGO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
          const Gap(10),
          for (final method in PaymentMethods.values) ...[
            _PaymentOption(
              method: method,
              selected: PaymentMethods.normalize(selected) == method,
              onTap: () => onChanged(method),
            ),
            if (method != PaymentMethods.values.last) const Gap(8),
          ],
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Icon(
              PaymentMethods.icon(method),
              color: selected ? AppColors.primary : AppColors.secondary,
              size: 20,
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PaymentMethods.label(method),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    PaymentMethods.description(method),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.secondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _TowRoutePreview extends StatelessWidget {
  final LocationEntity? origin;
  final LocationEntity? destination;
  final VoidCallback onSelectDestination;

  const _TowRoutePreview({
    required this.origin,
    required this.destination,
    required this.onSelectDestination,
  });

  @override
  Widget build(BuildContext context) {
    final originPoint = LatLng(
      origin?.lat ?? AppConstants.defaultLat,
      origin?.lng ?? AppConstants.defaultLng,
    );
    final destinationPoint = destination == null
        ? null
        : LatLng(destination!.lat, destination!.lng);
    final points = [
      originPoint,
      if (destinationPoint != null) destinationPoint,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emergency.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: AppResponsive.mapHeight(
              context,
              compact: 170,
              regular: 210,
              tablet: 250,
            ),
            child: FlutterMap(
              key: ValueKey(
                'tow-preview-${originPoint.latitude},${originPoint.longitude}-${destinationPoint?.latitude},${destinationPoint?.longitude}',
              ),
              options: MapOptions(
                initialCenter: destinationPoint == null
                    ? originPoint
                    : LatLng(
                        (originPoint.latitude + destinationPoint.latitude) / 2,
                        (originPoint.longitude + destinationPoint.longitude) / 2,
                      ),
                initialZoom: destinationPoint == null ? 14 : 12,
                initialCameraFit: points.length >= 2
                    ? CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(points),
                        padding: const EdgeInsets.all(44),
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConstants.osmTileUrl,
                  userAgentPackageName: 'com.autoresq.app',
                ),
                if (destinationPoint != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: AppColors.emergency.withValues(alpha: 0.62),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: originPoint,
                      width: 40,
                      height: 40,
                      child: _MapBubbleMarker(
                        color: AppColors.primary,
                        icon: Icons.my_location_rounded,
                      ),
                    ),
                    if (destinationPoint != null)
                      Marker(
                        point: destinationPoint,
                        width: 40,
                        height: 40,
                        child: _MapBubbleMarker(
                          color: AppColors.emergency,
                          icon: Icons.flag_rounded,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    destination?.address ??
                        'Selecciona el destino de traslado para ver la ruta de grúa.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
                const Gap(10),
                OutlinedButton(
                  onPressed: onSelectDestination,
                  child: Text(destination == null ? 'Destino' : 'Cambiar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBubbleMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapBubbleMarker({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final EmergencyPriceQuote? quote;
  final bool isLoading;
  final LocationEntity? destination;
  final VoidCallback onSelectDestination;

  const _PricingCard({
    required this.quote,
    required this.isLoading,
    required this.destination,
    required this.onSelectDestination,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            Gap(12),
            Expanded(
              child: Text(
                'Calculando posible cuota desde AutoResQ...',
              ),
            ),
          ],
        ),
      );
    }

    final current = quote;
    if (current == null) return const SizedBox.shrink();
    final isTow = current.pricingType == 'distance_based';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current.requiresManualReview
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.displayTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      current.displayMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(12),
          if (current.pricingStatus == 'pending_destination') ...[
            Text(
              current.destinationRequiredMessage ??
                  'Selecciona el destino para calcular una cuota referencial más precisa.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondary,
                height: 1.4,
              ),
            ),
            const Gap(12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSelectDestination,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Seleccionar destino'),
              ),
            ),
          ] else ...[
            if (isTow && current.towDistanceKm != null)
              _PricingLine(
                icon: Icons.route_outlined,
                text:
                    'Distancia de traslado: ${current.towDistanceKm!.toStringAsFixed(2)} km',
              ),
            if (isTow &&
                current.includedKm != null &&
                current.pricePerKm != null)
              _PricingLine(
                icon: Icons.info_outline,
                text:
                    'Incluye los primeros ${current.includedKm!.toStringAsFixed(0)} km. Luego ${AppHelpers.formatCurrency(current.pricePerKm!)}/km adicional.',
              ),
            _PricingLine(
              icon: Icons.lock_outline,
                text: current.pricingType == 'diagnostic'
                  ? 'Cualquier reparación, repuesto o servicio adicional deberá ser aprobado por ti.'
                  : 'El técnico no podrá cobrar adicionales sin tu aprobación.',
            ),
            if (current.distanceSource == 'haversine')
              const _PricingLine(
                icon: Icons.near_me_outlined,
                text: 'Cuota referencial según distancia aproximada.',
              ),
            if (current.requiresManualReview)
              const _PricingLine(
                icon: Icons.warning_amber_rounded,
                text: 'Esta es solo una cuota referencial y requiere revisión manual antes de confirmar un valor final.',
              ),
          ],
          if (destination != null) ...[
            const Gap(10),
            Text(
              destination!.address ?? 'Destino seleccionado',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondary,
              ),
            ),
          ],
          if (current.includesText?.isNotEmpty == true) ...[
            const Gap(12),
            Text(
              current.includesText!,
              style: const TextStyle(fontSize: 12, color: AppColors.onSurface),
            ),
          ],
          if (current.excludesText?.isNotEmpty == true) ...[
            const Gap(6),
            Text(
              current.excludesText!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PricingLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PricingLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.secondary),
          const Gap(8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Gradient Action Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GradientActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEmergency;

  const _GradientActionButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedScale(
        scale: onPressed == null ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: isEmergency
                ? AppColors.emergencyGradient
                : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: [
              BoxShadow(
                color: (isEmergency ? AppColors.emergency : AppColors.primary)
                    .withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else ...[
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Gap(12),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
