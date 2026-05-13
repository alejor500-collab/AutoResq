import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
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
  int _currentStep = 0;
  EmergencyAiAnalysisModel? _aiResult;
  EmergencyPriceQuote? _pricingQuote;
  LocationEntity? _destinationLocation;
  bool _aiAnalysisAttempted = false;
  bool _isPricingLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(mapNotifierProvider).currentLocation == null) {
        ref.read(mapNotifierProvider.notifier).getCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyzeAI() async {
    if (_descCtrl.text.trim().isEmpty) {
      AppHelpers.showSnackBar(context, 'Describe primero el problema',
          isError: true);
      return;
    }
    final mapState = ref.read(mapNotifierProvider);
    final result =
        await ref.read(emergencyNotifierProvider.notifier).analyzeWithAI(
              _descCtrl.text.trim(),
              lat: mapState.currentLocation?.lat,
              lng: mapState.currentLocation?.lng,
              address: mapState.currentLocation?.address,
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
      description: _descCtrl.text.trim(),
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
          displayMessage: 'Se creara la solicitud con revision de diagnostico.',
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

    AiAnalysis? aiAnalysis;
    if (_aiResult != null) {
      aiAnalysis = AiAnalysis(
        isValidEmergency: _aiResult!.isValidEmergency,
        emergencyType: _aiResult!.emergencyType,
        priority: _aiResult!.priority,
        userMessage: _aiResult!.userMessage,
        safetyRecommendation: _aiResult!.safetyRecommendation,
        technicianSummary: _aiResult!.technicianSummary,
        detectedRisks: _aiResult!.detectedRisks,
        requiresImmediateAttention: _aiResult!.requiresImmediateAttention,
        confidence: _aiResult!.confidence,
      );
    }

    final emergency =
        await ref.read(emergencyNotifierProvider.notifier).createEmergency(
              description: _descCtrl.text.trim(),
              lat: lat,
              lng: lng,
              address: address,
              aiAnalysis: aiAnalysis,
              skipAiAnalysis: _aiAnalysisAttempted && aiAnalysis == null,
              priceQuote: quote,
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
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
                      EdgeInsets.only(top: MediaQuery.of(context).padding.top),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          child: Text(
                            'Reportar Emergencia',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: AppColors.onSurface,
                            ),
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
            top: 64 + MediaQuery.of(context).padding.top,
            bottom: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Indicator
                  _StepProgress(currentStep: _currentStep),
                  const Gap(16),

                  // Step Title
                  Text(
                    _stepTitle,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -0.5,
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

                  // Step Content
                  if (_currentStep == 0)
                    _LocationStep(
                      mapState: mapState,
                      onEdit: _editEmergencyLocation,
                    ),
                  if (_currentStep == 1)
                    _DescriptionStep(
                      controller: _descCtrl,
                      isAnalyzing: emergencyState.isAnalyzingAI,
                    ),
                  if (_currentStep == 2)
                    _DiagnosticStep(
                      result: _aiResult,
                      pricingQuote: _pricingQuote,
                      isPricingLoading: _isPricingLoading,
                      destination: _destinationLocation,
                      onSelectDestination: _selectTowDestination,
                    ),
                ],
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
                      24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
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
                  child: _buildBottomButton(emergencyState),
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
        return 'Paso 3: Diagnostico Preliminar';
      default:
        return '';
    }
  }

  String get _stepSubtitle {
    switch (_currentStep) {
      case 0:
        return 'Confirma donde necesitas la asistencia tecnica.';
      case 1:
        return 'Describe el problema con tu vehiculo.';
      case 2:
        return 'Resultado del analisis inteligente.';
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
          label: emergencyState.isAnalyzingAI
              ? 'Analizando...'
              : 'Analizar con IA',
          icon: Icons.psychology,
          isLoading: emergencyState.isAnalyzingAI,
          onPressed: emergencyState.isAnalyzingAI ? null : _analyzeAI,
        );
      case 2:
        final needsDestination =
            _pricingQuote?.pricingStatus == 'pending_destination';
        return _GradientActionButton(
          label: _isPricingLoading
              ? 'Calculando tarifa...'
              : emergencyState.isLoading
                  ? 'Enviando...'
                  : needsDestination
                      ? 'Seleccionar destino'
                      : 'Publicar solicitud',
          icon: needsDestination ? Icons.map_outlined : Icons.arrow_forward,
          isLoading: emergencyState.isLoading || _isPricingLoading,
          onPressed: emergencyState.isLoading || _isPricingLoading
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

// ─── Step Progress Indicator ──────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int currentStep;

  const _StepProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: Container(
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

// ─── Step 1: Location ─────────────────────────────────────────────────────────

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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
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
            height: 200,
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
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location, color: Colors.white, size: 12),
                        Gap(6),
                        Text(
                          'DETECCION EN VIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Address info
          Padding(
            padding: const EdgeInsets.all(24),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 128,
                      ),
                      child: Text(
                        mapState.isLoading
                            ? 'Obteniendo ubicacion...'
                            : mapState.error ??
                                mapState.currentLocation?.address ??
                                'Ecuador',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
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
                const Text(
                  'Cobertura nacional en Ecuador',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondary,
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

// ─── Step 2: Description ──────────────────────────────────────────────────────

class _DescriptionStep extends StatefulWidget {
  final TextEditingController controller;
  final bool isAnalyzing;

  const _DescriptionStep({
    required this.controller,
    required this.isAnalyzing,
  });

  @override
  State<_DescriptionStep> createState() => _DescriptionStepState();
}

class _DescriptionStepState extends State<_DescriptionStep> {
  final _picker = ImagePicker();
  final List<XFile> _attachments = [];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (image == null || !mounted) return;
      setState(() => _attachments.add(image));
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DESCRIBE TU PROBLEMA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.secondary,
                ),
              ),
              const Gap(12),
              TextField(
                controller: widget.controller,
                minLines: 5,
                maxLines: 6,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.onSurface,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Ej: Mi auto no enciende y hace un ruido metalico al girar la llave...',
                  hintStyle: const TextStyle(
                    color: AppColors.secondaryContainer,
                    fontSize: 16,
                    height: 1.35,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
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
              if (_attachments.isNotEmpty) ...[
                const Gap(12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          '${_attachments.length} foto${_attachments.length == 1 ? '' : 's'} agregada${_attachments.length == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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

// ─── Step 3: AI Diagnostic ────────────────────────────────────────────────────

class _DiagnosticStep extends StatelessWidget {
  final EmergencyAiAnalysisModel? result;
  final EmergencyPriceQuote? pricingQuote;
  final bool isPricingLoading;
  final LocationEntity? destination;
  final VoidCallback onSelectDestination;

  const _DiagnosticStep({
    required this.result,
    required this.pricingQuote,
    required this.isPricingLoading,
    required this.destination,
    required this.onSelectDestination,
  });

  @override
  Widget build(BuildContext context) {
    final analysis = result;
    final tipo = analysis?.emergencyType ?? 'unknown';
    final priority = analysis?.priority ?? 'medium';
    final message = analysis?.userMessage ??
        'Crearemos la emergencia con tu descripcion original.';
    final safety = analysis?.safetyRecommendation ?? '';
    final failed = analysis == null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.04),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.03),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.build, color: Colors.white, size: 24),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DIAGNOSTICO PRELIMINAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      failed ? 'Analisis no disponible' : '$tipo - $priority',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (message.isNotEmpty || safety.isNotEmpty) ...[
                      const Gap(6),
                      Text(
                        safety.isNotEmpty ? '$message $safety' : message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.secondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Gap(20),
          const Row(
            children: [
              Expanded(
                child: _MiniInfoCard(
                  icon: Icons.timer,
                  label: 'TIEMPO ESTIMADO',
                  value: '15 - 20 min',
                ),
              ),
            ],
          ),
          const Gap(14),
          _PricingCard(
            quote: pricingQuote,
            isLoading: isPricingLoading,
            destination: destination,
            onSelectDestination: onSelectDestination,
          ),
        ],
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
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
                'Calculando tarifa desde AutoResQ...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                        letterSpacing: -0.4,
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
                  'Selecciona el destino para calcular un estimado mas preciso.',
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
                  ? 'Cualquier reparacion, repuesto o servicio adicional debera ser aprobado por ti.'
                  : 'El tecnico no podra cobrar adicionales sin tu aprobacion.',
            ),
            if (current.distanceSource == 'haversine')
              const _PricingLine(
                icon: Icons.near_me_outlined,
                text: 'Estimado segun distancia aproximada.',
              ),
            if (current.requiresManualReview)
              const _PricingLine(
                icon: Icons.warning_amber_rounded,
                text: 'Esta tarifa requiere revision manual antes de cerrar el valor final.',
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

// ─── Gradient Action Button ───────────────────────────────────────────────────

class _GradientActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GradientActionButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
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
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
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
