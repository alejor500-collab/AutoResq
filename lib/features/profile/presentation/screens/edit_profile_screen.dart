import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/technician_specialties.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/technician_specialty_dropdown_field.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../map/domain/entities/location_entity.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../map/presentation/widgets/location_picker_sheet.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  String? _selectedSpecialtyCode;

  bool _isUploadingAvatar = false;
  bool _isUpdatingLocation = false;
  bool _isResolvingLocationAddress = false;
  String? _locationAddress;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).value;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _selectedSpecialtyCode =
        TechnicianSpecialties.normalizeCode(user?.specialty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveSavedLocationAddress();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateLocation() async {
    final user = ref.read(authNotifierProvider).value!;
    final selected = await showLocationPickerSheet(
      context,
      title: 'Editar ubicacion guardada',
      initialLocation: user.lat != null && user.lng != null
          ? LocationEntity(
              lat: user.lat!,
              lng: user.lng!,
              address: _locationAddress ??
                  ref.read(mapNotifierProvider).currentLocation?.address,
            )
          : ref.read(mapNotifierProvider).currentLocation,
    );

    if (selected == null || !mounted) return;

    setState(() => _isUpdatingLocation = true);
    try {
      final supabase = ref.read(supabaseClientProvider);

      if (user.isTechnician) {
        await supabase.from(AppConstants.tableTecnicos).update({
          'ubicacion_lat': selected.lat,
          'ubicacion_lng': selected.lng,
        }).eq('usuario_id', user.id);
      }

      final updated = user.copyWith(
        lat: selected.lat,
        lng: selected.lng,
      );
      _locationAddress = selected.address;
      ref.read(authNotifierProvider.notifier).refreshUser(updated);
      ref.read(currentUserProvider.notifier).state = updated;
      ref.read(mapNotifierProvider.notifier).setLocation(selected);

      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Ubicacion actualizada',
          isSuccess: true,
        );
      }
    } catch (_) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Error al guardar ubicacion',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (xFile == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final user = ref.read(authNotifierProvider).value!;
      final bytes = await xFile.readAsBytes();
      final fileName = xFile.name.isNotEmpty ? xFile.name : xFile.path;
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final path = '${user.id}/avatar.$ext';

      final supabase = ref.read(supabaseClientProvider);
      await supabase.storage.from(AppConstants.bucketAvatars).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mimeType),
          );
      final url = supabase.storage
          .from(AppConstants.bucketAvatars)
          .getPublicUrl(path);
      final avatarUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      final updated = user.copyWith(avatarUrl: avatarUrl);
      final ok = await ref
          .read(authNotifierProvider.notifier)
          .updateProfile(updated);

      if (mounted) {
        if (ok) {
          AppHelpers.showSnackBar(context, 'Foto actualizada', isSuccess: true);
        } else {
          AppHelpers.showSnackBar(
            context,
            'Error al guardar foto',
            isError: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'Error al subir foto', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _resolveSavedLocationAddress() async {
    final user = ref.read(authNotifierProvider).value;
    final lat = user?.lat;
    final lng = user?.lng;
    if (lat == null || lng == null) return;

    final cached = ref.read(mapNotifierProvider).currentLocation;
    if (cached?.address != null && cached?.lat == lat && cached?.lng == lng) {
      setState(() => _locationAddress = cached!.address);
      return;
    }

    setState(() => _isResolvingLocationAddress = true);
    try {
      final address = await DioClient().reverseGeocode(lat, lng);
      if (!mounted) return;
      setState(() => _locationAddress = address);
    } finally {
      if (mounted) setState(() => _isResolvingLocationAddress = false);
    }
  }

  String _savedLocationLabel(AppUser? user) {
    if (user?.lat == null || user?.lng == null) {
      return 'Sin ubicacion guardada';
    }
    if (_isResolvingLocationAddress) {
      return 'Resolviendo direccion...';
    }
    final address = _locationAddress?.trim();
    if (address != null && address.isNotEmpty) {
      return address;
    }
    return 'Ubicacion guardada en Ecuador';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authNotifierProvider).value!;
    final updated = user.copyWith(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      specialty: user.isTechnician ? _selectedSpecialtyCode : user.specialty,
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
    final emailCtrl = TextEditingController(text: user?.email ?? '');

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
              Center(
                child: GestureDetector(
                  onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  child: Stack(
                    children: [
                      UserAvatar(
                        imageUrl: user?.avatarUrl,
                        name: user?.name ?? '',
                        radius: 48,
                      ),
                      if (_isUploadingAvatar)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (!_isUploadingAvatar)
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
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Gap(8),
              Text(
                'Toca para cambiar foto',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
              const Gap(28),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: Validators.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                hint: '0991234567',
                textInputAction: TextInputAction.next,
              ),
              if (user?.isTechnician == true) ...[
                const Gap(14),
                TechnicianSpecialtyDropdownField(
                  value: _selectedSpecialtyCode,
                  validator: (value) =>
                      TechnicianSpecialties.isValidCode(value)
                          ? null
                          : 'Selecciona una especialidad tecnica',
                  onChanged: (value) => setState(
                    () => _selectedSpecialtyCode = value,
                  ),
                ),
                const Gap(4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Tu especialidad es visible para los conductores que solicitan asistencia.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Gap(14),
              AppTextField(
                label: AppStrings.email,
                controller: emailCtrl,
                readOnly: true,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                suffixIcon: const Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ),
              const Gap(14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusCard),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _savedLocationLabel(user),
                        style: TextStyle(
                          fontSize: 13,
                          color: user?.lat != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isUpdatingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : TextButton(
                            onPressed: _updateLocation,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Editar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ],
                ),
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
