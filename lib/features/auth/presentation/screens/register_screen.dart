import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/navigation_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final int? initialRole;
  const RegisterScreen({super.key, this.initialRole});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  late int _selectedRole;
  String? _selectedSpecialtyCode;
  Uint8List? _cedulaBytes;
  String _cedulaExt = 'jpg';

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _specialtyCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String get _roleName => _selectedRole == 0
      ? AppConstants.roleDriver
      : AppConstants.roleTechnician;

  Future<void> _pickCedula() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    final nameForExt = xFile.name.isNotEmpty ? xFile.name : xFile.path;
    setState(() {
      _cedulaBytes = bytes;
      _cedulaExt = nameForExt.split('.').last.toLowerCase();
    });
  }

  Future<void> _loginWithGoogle() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    final success = await notifier.loginWithGoogle();
    if (!mounted) return;
    if (success) {
      _navigateByRole();
    } else {
      final error = ref.read(authNotifierProvider).error;
      AppHelpers.showSnackBar(
        context,
        error?.toString() ?? 'Error al iniciar sesión con Google',
        isError: true,
      );
    }
  }

  void _navigateByRole() {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    switch (user.role) {
      case AppConstants.roleDriver:
        context.go(AppRoutes.driverHome);
      case AppConstants.roleTechnician:
        context.go(
          user.isApproved ? AppRoutes.technicianHome : AppRoutes.driverHome,
        );
      case AppConstants.roleAdmin:
        context.go(AppRoutes.adminDashboard);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordCtrl.text != _confirmPassCtrl.text) {
      AppHelpers.showSnackBar(context, 'Las contraseñas no coinciden',
          isError: true);
      return;
    }

    if (_selectedRole == 1 && _cedulaBytes == null) {
      AppHelpers.showSnackBar(
        context,
        'La foto de cédula es obligatoria para técnicos',
        isError: true,
      );
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);
    final success = await notifier.register(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      role: _roleName,
      specialty: _selectedRole == 1 ? _selectedSpecialtyCode : null,
    );

    if (!mounted) return;

    if (success) {
      if (_selectedRole == 1 && _cedulaBytes != null) {
        final user = ref.read(authNotifierProvider).value;
        if (user == null) {
          if (mounted) {
            AppHelpers.showSnackBar(
              context,
              'No se pudo subir el documento de identidad.',
              isError: true,
            );
          }
          return;
        }
        try {
          final supabase = ref.read(supabaseClientProvider);
          final ext = _cedulaExt.isEmpty ? 'jpg' : _cedulaExt;
          final mimeType = switch (ext) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          };
          final path =
              '${user.id}/cedula_${DateTime.now().millisecondsSinceEpoch}.$ext';
          await supabase.storage.from(AppConstants.bucketAvatars).uploadBinary(
              path, _cedulaBytes!,
              fileOptions: FileOptions(upsert: true, contentType: mimeType));
          final url = supabase.storage
              .from(AppConstants.bucketAvatars)
              .getPublicUrl(path);
          final rows = await supabase
              .from(AppConstants.tableTecnicos)
              .update({'url_credencial': url})
              .eq('usuario_id', user.id)
              .select('url_credencial');
          if (rows.isEmpty) {
            if (mounted) {
              AppHelpers.showSnackBar(
                context,
                'No se pudo subir el documento de identidad.',
                isError: true,
              );
            }
            return;
          }
        } catch (e) {
          if (mounted) {
            AppHelpers.showSnackBar(
              context,
              'No se pudo subir el documento de identidad.',
              isError: true,
            );
          }
          return;
        }
        // Upload completo. El router redirige al técnico a la pantalla de espera.
        if (!mounted) return;
        AppHelpers.showSnackBar(
          context,
          'Solicitud tecnica enviada. Puedes usar AutoResQ como conductor.',
          isSuccess: true,
        );
        context.go(AppRoutes.driverHome);
        return;
      }
      _navigateByRole();
    } else {
      final error = ref.read(authNotifierProvider).error;
      AppHelpers.showSnackBar(
        context,
        error?.toString() ?? 'Error al registrar',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Back button
                    GestureDetector(
                      onTap: () => safeBack(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back,
                            size: 20, color: AppColors.secondary),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Hero role icon landing target (animates in from RoleSelectionScreen)
                    if (widget.initialRole != null) ...[
                      Hero(
                        tag: widget.initialRole == 0
                            ? 'hero_role_conductor'
                            : 'hero_role_tecnico',
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: (widget.initialRole == 0
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF1E88E5))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            widget.initialRole == 0
                                ? Icons.directions_car_rounded
                                : Icons.build_rounded,
                            color: widget.initialRole == 0
                                ? const Color(0xFFE53935)
                                : const Color(0xFF1E88E5),
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Header
                    const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Completa tus datos para empezar',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.secondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Role selector
                    _buildRoleSelector(),
                    const SizedBox(height: 28),

                    // Name
                    AppTextField(
                      label: 'Nombre completo',
                      hint: 'Juan Pérez',
                      controller: _nameCtrl,
                      validator: Validators.name,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.person_outline,
                          size: 20, color: AppColors.secondary),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]')),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Email
                    AppTextField(
                      label: 'Email',
                      hint: 'nombre@ejemplo.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.email_outlined,
                          size: 20, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    AppTextField(
                      label: 'Teléfono',
                      hint: '0991234567',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.phone_outlined,
                          size: 20, color: AppColors.secondary),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),

                    // Specialty (only for technician)
                    if (_selectedRole == 1) ...[
                      AppTextField(
                        label: 'Especialidad',
                        hint: 'Ej: Mecánica automotriz',
                        controller: _specialtyCtrl,
                        validator: (v) => Validators.minLength(v, 3),
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.build_outlined,
                            size: 20, color: AppColors.secondary),
                      ),
                      const SizedBox(height: 16),
                      // Cedula photo picker
                      GestureDetector(
                        onTap: _pickCedula,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _cedulaBytes != null
                                ? const Color(0xFF1E88E5).withValues(alpha: 0.08)
                                : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _cedulaBytes != null
                                  ? const Color(0xFF1E88E5).withValues(alpha: 0.3)
                                  : AppColors.surfaceContainerHigh,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (_cedulaBytes != null
                                          ? const Color(0xFF1E88E5)
                                          : AppColors.secondary)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _cedulaBytes != null
                                      ? Icons.check_circle_outline
                                      : Icons.badge_outlined,
                                  color: _cedulaBytes != null
                                      ? const Color(0xFF1E88E5)
                                      : AppColors.secondary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _cedulaBytes != null
                                          ? 'Cédula capturada'
                                          : 'Foto de cédula *',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _cedulaBytes != null
                                            ? const Color(0xFF1E88E5)
                                            : AppColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _cedulaBytes != null
                                          ? 'Toca para cambiar'
                                          : 'Requerida para verificación técnica',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.secondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.camera_alt_outlined,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Password
                    AppTextField(
                      label: 'Contraseña',
                      hint: '••••••••',
                      controller: _passwordCtrl,
                      obscureText: true,
                      validator: Validators.password,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Confirm password
                    AppTextField(
                      label: 'Confirmar contraseña',
                      hint: '••••••••',
                      controller: _confirmPassCtrl,
                      obscureText: true,
                      validator: Validators.password,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 32),

                    // Register button
                    AppButton(
                      label: 'Crear cuenta',
                      onPressed: _register,
                      isLoading: isLoading,
                      suffixIcon: const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(height: 20),

                    // Divider con "o"
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: AppColors.outline.withValues(alpha: 0.4))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: AppColors.outline.withValues(alpha: 0.4))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botón Google
                    _GoogleRegisterButton(
                        onPressed: isLoading ? null : _loginWithGoogle),
                    const SizedBox(height: 24),

                    // Login link
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '¿Ya tienes cuenta? ',
                            style: TextStyle(
                                color: AppColors.secondary, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () => safeBack(
                              context,
                              fallback: AppRoutes.login,
                            ),
                            child: const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        children: [
          _rolePill('Conductor', 0),
          _rolePill('Técnico', 1),
        ],
      ),
    );
  }

  Widget _rolePill(String label, int index) {
    final isActive = _selectedRole == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedRole = index;
          if (index != 1) {
            _selectedSpecialtyCode = null;
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.onSurface.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.primary : AppColors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleRegisterButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _GoogleRegisterButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(painter: _GoogleLogoPainter()),
              ),
              const SizedBox(width: 12),
              const Text(
                'Registrarse con Google',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C4043),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 3.5;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect =
        Rect.fromCircle(center: Offset.zero, radius: radius - strokeWidth / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    arcPaint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -0.52, -1.57, false, arcPaint);

    arcPaint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -2.09, -1.57, false, arcPaint);

    arcPaint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 2.62, 1.57, false, arcPaint);

    arcPaint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.52, 1.57, false, arcPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset.zero, Offset(radius - strokeWidth / 2, 0), linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
