import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';
import '../providers/tecnico_status_provider.dart';
import 'app_text_field.dart';

/// Opens the technician-request bottom sheet.
/// Returns `true` if the request was successfully submitted.
/// Set [isResubmission] to `true` when a rejected technician is re-sending.
Future<bool?> showTechnicianRequestSheet(
  BuildContext context,
  String userId, {
  bool isResubmission = false,
  String? currentSpecialty,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TechnicianRequestSheet(
      userId: userId,
      isResubmission: isResubmission,
      currentSpecialty: currentSpecialty,
    ),
  );
}

class TechnicianRequestSheet extends ConsumerStatefulWidget {
  final String userId;
  final bool isResubmission;
  final String? currentSpecialty;

  const TechnicianRequestSheet({
    super.key,
    required this.userId,
    this.isResubmission = false,
    this.currentSpecialty,
  });

  @override
  ConsumerState<TechnicianRequestSheet> createState() =>
      _TechnicianRequestSheetState();
}

class _TechnicianRequestSheetState
    extends ConsumerState<TechnicianRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  Uint8List? _cedulaBytes;
  String _cedulaExt = 'jpg';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(authNotifierProvider).value;
    _nameCtrl.text = current?.name ?? '';
    _phoneCtrl.text = current?.phone ?? '';
    _specialtyCtrl.text = widget.currentSpecialty ?? current?.specialty ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

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
              title: const Text('Elegir de galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final xFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (xFile == null || !mounted) return;

    final bytes = await xFile.readAsBytes();
    final nameForExt = xFile.name.isNotEmpty ? xFile.name : xFile.path;
    setState(() {
      _cedulaBytes = bytes;
      _cedulaExt = nameForExt.split('.').last.toLowerCase();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cedulaBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La foto de cedula es obligatoria')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final specialty = _specialtyCtrl.text.trim();
      final ext = _cedulaExt.isEmpty ? 'jpg' : _cedulaExt;
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${widget.userId}/cedula_$timestamp.$ext';

      await supabase.storage.from(AppConstants.bucketAvatars).uploadBinary(
            path,
            _cedulaBytes!,
            fileOptions: FileOptions(upsert: true, contentType: mimeType),
          );
      final cedulaUrl =
          supabase.storage.from(AppConstants.bucketAvatars).getPublicUrl(path);

      await supabase.from(AppConstants.tableUsuarios).update({
        'nombre': name,
        'telefono': phone,
      }).eq('id', widget.userId);

      await supabase.from(AppConstants.tableTecnicos).upsert({
        'usuario_id': widget.userId,
        'especialidad': specialty,
        'estado_verificacion': AppConstants.verificationPending,
        'disponible': false,
        'url_credencial': cedulaUrl,
        if (widget.isResubmission) 'motivo_rechazo': null,
      }, onConflict: 'usuario_id');

      final current = ref.read(authNotifierProvider).value;
      if (current != null) {
        final refreshed = AppUser(
          id: current.id,
          email: current.email,
          name: name,
          phone: phone,
          role: current.role,
          avatarUrl: current.avatarUrl,
          rating: current.rating,
          totalServices: current.totalServices,
          isAvailable: false,
          isApproved: current.isApproved,
          specialty: specialty,
          lat: current.lat,
          lng: current.lng,
          createdAt: current.createdAt,
          verificationStatus: AppConstants.verificationPending,
          rejectionReason: null,
        );
        ref.read(authNotifierProvider.notifier).refreshUser(refreshed);
        ref.read(currentUserProvider.notifier).state = refreshed;
      }
      ref.invalidate(tecnicoStatusProvider);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar solicitud: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.isResubmission
                    ? 'Enviar nueva solicitud'
                    : 'Solicitar modo Tecnico',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isResubmission
                    ? 'Corrige tus datos y sube una nueva foto de cedula. El administrador revisara tu solicitud.'
                    : 'El administrador revisara tu solicitud antes de aprobarla.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Nombre completo',
                hint: 'Juan Perez',
                controller: _nameCtrl,
                validator: Validators.name,
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Telefono',
                hint: '0991234567',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Especialidad tecnica',
                hint: 'Ej: Mecanica automotriz, Electricidad',
                controller: _specialtyCtrl,
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Ingresa tu especialidad (minimo 3 caracteres)'
                    : null,
                prefixIcon: const Icon(Icons.build_outlined, size: 20),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isSubmitting ? null : _pickCedula,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cedulaBytes != null
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _cedulaBytes != null
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (_cedulaBytes != null
                                  ? AppColors.primary
                                  : AppColors.textHint)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _cedulaBytes != null
                              ? Icons.check_circle_outline
                              : Icons.badge_outlined,
                          color: _cedulaBytes != null
                              ? AppColors.primary
                              : AppColors.textHint,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _cedulaBytes != null
                                  ? 'Cedula capturada'
                                  : 'Foto de cedula *',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _cedulaBytes != null
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _cedulaBytes != null
                                  ? 'Toca para cambiar'
                                  : 'Requerida para verificacion',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.textHint,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusButton,
                      ),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enviar solicitud',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
