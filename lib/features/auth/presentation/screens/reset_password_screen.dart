import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Confirma la contraseña';
    if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final ds = ref.read(authRemoteDataSourceProvider);
      await ds.updatePassword(_passwordCtrl.text);

      // End the recovery session so the user logs in fresh
      await ref.read(authNotifierProvider.notifier).logout();

      if (!mounted) return;
      AppHelpers.showSnackBar(
        context,
        'Contraseña actualizada. Inicia sesión.',
        isSuccess: true,
      );
      context.go(AppRoutes.login);
    } catch (_) {
      if (!mounted) return;
      AppHelpers.showSnackBar(
        context,
        'No se pudo actualizar la contraseña. Intenta de nuevo.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const Gap(24),
              const Text(
                'Nueva contraseña',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Gap(8),
              const Text(
                'Elige una contraseña segura de al menos 8 caracteres.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Gap(32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Nueva contraseña',
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      prefixIcon:
                          const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const Gap(14),
                    AppTextField(
                      label: 'Confirmar contraseña',
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      validator: _validateConfirm,
                      prefixIcon:
                          const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              const Gap(32),
              AppButton(
                label: 'Guardar contraseña',
                onPressed: _submit,
                isLoading: _isLoading,
                height: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
