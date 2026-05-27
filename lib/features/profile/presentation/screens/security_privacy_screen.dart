import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class SecurityPrivacyScreen extends ConsumerStatefulWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  ConsumerState<SecurityPrivacyScreen> createState() =>
      _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState
    extends ConsumerState<SecurityPrivacyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isUpdatingPassword = false;
  bool _isSendingReset = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdatingPassword = true);
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .updatePassword(_passwordCtrl.text);
    if (!mounted) return;
    setState(() => _isUpdatingPassword = false);

    if (ok) {
      _passwordCtrl.clear();
      _confirmCtrl.clear();
    }
    AppHelpers.showSnackBar(
      context,
      ok
          ? 'Contrasena actualizada correctamente.'
          : 'No se pudo actualizar la contrasena.',
      isError: !ok,
    );
  }

  Future<void> _sendResetEmail() async {
    final email = ref.read(authNotifierProvider).valueOrNull?.email;
    if (email == null || email.isEmpty) return;

    setState(() => _isSendingReset = true);
    final ok =
        await ref.read(authNotifierProvider.notifier).sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _isSendingReset = false);

    AppHelpers.showSnackBar(
      context,
      ok
          ? 'Enlace de recuperacion enviado a $email.'
          : 'No se pudo enviar el enlace de recuperacion.',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Seguridad y privacidad'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const Text(
              'Proteccion de cuenta',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: 0,
              ),
            ),
            const Gap(8),
            const Text(
              'Administra tu acceso y revisa que datos usa AutoResQ para operar tu perfil.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
                height: 1.45,
              ),
            ),
            const Gap(24),
            _SectionCard(
              title: 'Cambiar contrasena',
              icon: Icons.lock_reset_rounded,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Nueva contrasena',
                      controller: _passwordCtrl,
                      obscureText: true,
                      validator: Validators.password,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                    const Gap(14),
                    AppTextField(
                      label: 'Confirmar contrasena',
                      controller: _confirmCtrl,
                      obscureText: true,
                      validator: (value) => Validators.confirmPassword(
                        value,
                        _passwordCtrl.text,
                      ),
                      prefixIcon:
                          const Icon(Icons.verified_user_outlined),
                    ),
                    const Gap(18),
                    AppButton(
                      label: 'Actualizar contrasena',
                      isLoading: _isUpdatingPassword,
                      onPressed:
                          _isUpdatingPassword ? null : _updatePassword,
                      prefixIcon:
                          const Icon(Icons.check_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(16),
            _SectionCard(
              title: 'Recuperacion de acceso',
              icon: Icons.mark_email_read_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.email ?? 'Correo no disponible',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Gap(6),
                  const Text(
                    'Envia un enlace seguro de restablecimiento al correo de tu cuenta.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondary,
                      height: 1.4,
                    ),
                  ),
                  const Gap(16),
                  AppButton(
                    label: 'Enviar enlace',
                    variant: AppButtonVariant.secondary,
                    isLoading: _isSendingReset,
                    onPressed: _isSendingReset ? null : _sendResetEmail,
                    prefixIcon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
            const Gap(16),
            _SectionCard(
              title: 'Privacidad operativa',
              icon: Icons.privacy_tip_outlined,
              child: Column(
                children: [
                  _PrivacyRow(
                    icon: Icons.badge_outlined,
                    title: 'Datos de perfil',
                    body:
                        'Nombre y telefono se comparten solo cuando hay una solicitud o servicio activo.',
                  ),
                  const Gap(14),
                  _PrivacyRow(
                    icon: Icons.location_on_outlined,
                    title: 'Ubicacion',
                    body:
                        'La ubicacion se usa para asignar asistencia y calcular rutas del servicio.',
                  ),
                  const Gap(14),
                  _PrivacyRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notificaciones',
                    body:
                        'Las alertas se vinculan a tu usuario para avisos de emergencia, mensajes y cambios de estado.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const Gap(10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const Gap(18),
          child,
        ],
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PrivacyRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const Gap(3),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12,
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
