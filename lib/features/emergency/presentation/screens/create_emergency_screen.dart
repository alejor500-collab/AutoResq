import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../map/presentation/providers/map_provider.dart';
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
  Map<String, dynamic>? _aiResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapNotifierProvider.notifier).getCurrentLocation();
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
    final result = await ref
        .read(emergencyNotifierProvider.notifier)
        .analyzeWithAI(_descCtrl.text.trim());
    if (result != null && mounted) {
      setState(() {
        _aiResult = result;
        _currentStep = 2;
      });
    }
  }

  Future<void> _createEmergency() async {
    final mapState = ref.read(mapNotifierProvider);
    final lat = mapState.currentLocation?.lat ?? AppConstants.defaultLat;
    final lng = mapState.currentLocation?.lng ?? AppConstants.defaultLng;
    final address = mapState.currentLocation?.address;

    AiAnalysis? aiAnalysis;
    if (_aiResult != null) {
      aiAnalysis = AiAnalysis(
        tipo: _aiResult!['tipo']?.toString() ?? '',
        sugerencia: _aiResult!['sugerencia']?.toString() ?? '',
        descripcionBreve: _aiResult!['descripcion_breve']?.toString() ?? '',
      );
    }

    final emergency = await ref
        .read(emergencyNotifierProvider.notifier)
        .createEmergency(
          description: _descCtrl.text.trim(),
          lat: lat,
          lng: lng,
          address: address,
          aiAnalysis: aiAnalysis,
        );

    if (!mounted) return;

    if (emergency != null) {
      context.pushReplacement(AppRoutes.emergencyStatus, extra: emergency.id);
    } else {
      final error = ref.read(emergencyNotifierProvider).error;
      AppHelpers.showSnackBar(context, error ?? 'Error al crear emergencia',
          isError: true);
    }
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
                    color: Colors.white.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withOpacity(0.06),
                        blurRadius: 40,
                        offset: const Offset(0, 40),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_currentStep > 0) {
                              setState(() => _currentStep--);
                            } else {
                              context.pop();
                            }
                          },
                          child: Icon(
                            _currentStep > 0 ? Icons.arrow_back : Icons.close,
                            color: AppColors.secondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Reportar Emergencia',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
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
                    _LocationStep(mapState: mapState),
                  if (_currentStep == 1)
                    _DescriptionStep(
                      controller: _descCtrl,
                      isAnalyzing: emergencyState.isAnalyzingAI,
                    ),
                  if (_currentStep == 2 && _aiResult != null)
                    _DiagnosticStep(result: _aiResult!),
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
                    color: Colors.white.withOpacity(0.9),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withOpacity(0.04),
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
        return _GradientActionButton(
          label: emergencyState.isLoading
              ? 'Enviando...'
              : 'Buscar tecnico cercano',
          icon: Icons.arrow_forward,
          isLoading: emergencyState.isLoading,
          onPressed: emergencyState.isLoading ? null : _createEmergency,
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

  const _LocationStep({required this.mapState});

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
            color: AppColors.onSurface.withOpacity(0.04),
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
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                              border: Border.all(
                                  color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
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
                        colors: [Colors.transparent, Colors.black.withOpacity(0.2)],
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
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
                Text(
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
                  children: [
                    Expanded(
                      child: Text(
                        mapState.isLoading
                            ? 'Obteniendo ubicacion...'
                            : mapState.currentLocation?.address ??
                                'Riobamba, Ecuador',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
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
                  'Riobamba, Chimborazo',
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

class _DescriptionStep extends StatelessWidget {
  final TextEditingController controller;
  final bool isAnalyzing;

  const _DescriptionStep({
    required this.controller,
    required this.isAnalyzing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI analyzing badge
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.psychology, size: 14, color: AppColors.tertiary),
                  const Gap(6),
                  Text(
                    'IA analizando tipo de falla...',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              Text(
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
                controller: controller,
                maxLines: 5,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.onSurface,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Ej: Mi auto no enciende y hace un ruido metalico al girar la llave...',
                  hintStyle: TextStyle(
                    color: AppColors.secondaryContainer,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const Gap(16),
              // Action chips
              Row(
                children: [
                  _ActionChip(
                    icon: Icons.mic,
                    label: 'Nota de voz',
                    onTap: () {},
                  ),
                  const Gap(8),
                  _ActionChip(
                    icon: Icons.photo_camera,
                    label: 'Subir foto',
                    onTap: () {},
                  ),
                ],
              ),
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
  final Map<String, dynamic> result;

  const _DiagnosticStep({required this.result});

  @override
  Widget build(BuildContext context) {
    final tipo = result['tipo']?.toString() ?? 'Desconocido';
    final sugerencia = result['sugerencia']?.toString() ?? '';
    final desc = result['descripcion_breve']?.toString() ?? '';

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.tertiary.withOpacity(0.05),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tertiary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.03),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tertiary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.build, color: Colors.white, size: 24),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sugerencia de la IA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tertiary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      'Falla Mecanica ($tipo)',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (desc.isNotEmpty || sugerencia.isNotEmpty) ...[
                      const Gap(6),
                      Text(
                        desc.isNotEmpty ? desc : sugerencia,
                        style: TextStyle(
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

          // Stats grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: AppColors.tertiary, size: 20),
                      const Gap(10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TIEMPO ESTIMADO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Text(
                            '15 - 20 min',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payments, color: AppColors.tertiary, size: 20),
                      const Gap(10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COSTO BASE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Text(
                            '\$25.00',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                color: AppColors.primary.withOpacity(0.2),
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
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
