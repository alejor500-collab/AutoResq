import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../map/domain/entities/location_entity.dart';
import '../../../map/presentation/providers/map_provider.dart';

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

  bool _isUploadingAvatar = false;
  bool _isUpdatingLocation = false;

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

  Future<void> _updateLocation() async {
    setState(() => _isUpdatingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppHelpers.showSnackBar(
            context, 'Activa el servicio de ubicación', isError: true);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppHelpers.showSnackBar(
              context, 'Permiso de ubicación denegado', isError: true);
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppHelpers.showSnackBar(
            context,
            'Permiso denegado permanentemente. Actívalo en Configuración',
            isError: true,
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final address = await DioClient()
          .reverseGeocode(position.latitude, position.longitude);

      final user = ref.read(authNotifierProvider).value!;
      final supabase = ref.read(supabaseClientProvider);

      await supabase.from(AppConstants.tableUsuarios).update({
        'lat': position.latitude,
        'lng': position.longitude,
      }).eq('id', user.id);

      if (user.isTechnician) {
        await supabase.from(AppConstants.tableTecnicos).update({
          'lat': position.latitude,
          'lng': position.longitude,
        }).eq('usuario_id', user.id);

        await supabase.from(AppConstants.tableUbicacionesTecnico).upsert({
          'usuario_id': user.id,
          'lat': position.latitude,
          'lng': position.longitude,
          'actualizado_en': DateTime.now().toIso8601String(),
        });
      }

      final updated = user.copyWith(
        lat: position.latitude,
        lng: position.longitude,
      );
      ref.read(authNotifierProvider.notifier).refreshUser(updated);
      ref.read(currentUserProvider.notifier).state = updated;
      ref.read(mapNotifierProvider.notifier).setLocation(
        LocationEntity(
          lat: position.latitude,
          lng: position.longitude,
          address: address,
        ),
      );

      if (mounted) {
        AppHelpers.showSnackBar(
          context, 'Ubicación actualizada', isSuccess: true);
      }
    } catch (_) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context, 'Error al obtener ubicación', isError: true);
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
          AppHelpers.showSnackBar(context, 'Error al guardar foto',
              isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'Error al subir foto', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
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
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

              // Location update
              const Gap(14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusCard),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user?.lat != null
                            ? '${user!.lat!.toStringAsFixed(5)}, '
                                '${user.lng!.toStringAsFixed(5)}'
                            : 'Sin ubicación guardada',
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
                                  horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Actualizar',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
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
