import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/user_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _specialtyCtrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).value;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _specialtyCtrl = TextEditingController(text: user?.specialty ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authNotifierProvider).value!;
    final updated = user.copyWith(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      specialty: _specialtyCtrl.text.trim().isEmpty
          ? null
          : _specialtyCtrl.text.trim(),
    );

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(updated);

    if (!mounted) return;

    if (ok) {
      AppHelpers.showSnackBar(
        context,
        'Perfil actualizado exitosamente',
        isSuccess: true,
      );
      context.pop();
    } else {
      AppHelpers.showSnackBar(
        context,
        'No se pudo actualizar el perfil',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.value;
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          AppStrings.editProfile,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Gap(8),
              // Avatar
              Center(
                child: Stack(
                  children: [
                    UserAvatar(
                      imageUrl: user?.avatarUrl,
                      name: user?.name ?? '',
                      radius: 48,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Text(
                'Toca para cambiar foto',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary.withOpacity(0.7),
                ),
              ),
              const Gap(28),

              // Fields
              AppTextField(
                label: AppStrings.name,
                controller: _nameCtrl,
                validator: Validators.name,
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                textInputAction: TextInputAction.next,
              ),
              const Gap(14),
              AppTextField(
                label: AppStrings.phone,
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                hint: '0991234567',
                textInputAction: TextInputAction.next,
              ),

              if (user?.isTechnician == true) ...[
                const Gap(14),
                AppTextField(
                  label: AppStrings.specialty,
                  controller: _specialtyCtrl,
                  prefixIcon: const Icon(Icons.build_outlined, size: 20),
                  textInputAction: TextInputAction.done,
                ),
              ],

              // Email (read only)
              const Gap(14),
              AppTextField(
                label: AppStrings.email,
                controller: TextEditingController(text: user?.email ?? ''),
                readOnly: true,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                suffixIcon: const Icon(Icons.lock_outline,
                    size: 16, color: AppColors.textHint),
              ),

              const Gap(32),
              AppButton(
                label: AppStrings.save,
                onPressed: _save,
                isLoading: isLoading,
                height: 52,
              ),
              const Gap(12),
              AppButton(
                label: AppStrings.cancel,
                onPressed: () => context.pop(),
                variant: AppButtonVariant.ghost,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
