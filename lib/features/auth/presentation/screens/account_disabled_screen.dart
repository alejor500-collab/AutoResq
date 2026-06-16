import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

final latestReactivationRequestProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  final rows = await ref
      .read(supabaseClientProvider)
      .from(AppConstants.tableAccountReactivationRequests)
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(1);
  final list = List<Map<String, dynamic>>.from(rows);
  return list.isEmpty ? null : list.first;
});

class AccountDisabledScreen extends ConsumerStatefulWidget {
  const AccountDisabledScreen({super.key});

  @override
  ConsumerState<AccountDisabledScreen> createState() =>
      _AccountDisabledScreenState();
}

class _AccountDisabledScreenState extends ConsumerState<AccountDisabledScreen> {
  final _reasonCtrl = TextEditingController();
  Uint8List? _attachmentBytes;
  String? _attachmentName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      if (!mounted) return;
      AppHelpers.showSnackBar(
        context,
        'No se pudo leer el archivo seleccionado.',
        isError: true,
      );
      return;
    }
    setState(() {
      _attachmentBytes = file.bytes;
      _attachmentName = file.name;
    });
  }

  Future<void> _submit() async {
    final user = ref.read(authNotifierProvider).value;
    final reason = _reasonCtrl.text.trim();
    if (user == null || user.isActive) return;
    if (reason.length < 12) {
      AppHelpers.showSnackBar(
        context,
        'Explica tu solicitud con al menos 12 caracteres.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final client = ref.read(supabaseClientProvider);
      String? evidenceUrl;
      final fileName = _attachmentName;
      if (_attachmentBytes != null && fileName != null) {
        final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final path =
            '${user.id}/reactivation_${DateTime.now().millisecondsSinceEpoch}_$safeName';
        await client.storage.from(AppConstants.bucketAvatars).uploadBinary(
              path,
              _attachmentBytes!,
              fileOptions: FileOptions(
                upsert: true,
                contentType: _contentType(fileName),
              ),
            );
        evidenceUrl =
            client.storage.from(AppConstants.bucketAvatars).getPublicUrl(path);
      }

      await client.from(AppConstants.tableAccountReactivationRequests).insert({
        'user_id': user.id,
        'reason': reason,
        if (evidenceUrl != null) 'evidence_url': evidenceUrl,
        if (fileName != null) 'evidence_file_name': fileName,
      });

      _reasonCtrl.clear();
      setState(() {
        _attachmentBytes = null;
        _attachmentName = null;
      });
      ref.invalidate(latestReactivationRequestProvider(user.id));
      if (!mounted) return;
      AppHelpers.showSnackBar(
        context,
        'Solicitud enviada. Un administrador la revisara.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      final text = e.toString().contains('duplicate key')
          ? 'Ya tienes una solicitud pendiente de revision.'
          : 'No se pudo enviar la solicitud: $e';
      AppHelpers.showSnackBar(context, text, isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _contentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;
    final latestRequest = user == null
        ? const AsyncValue<Map<String, dynamic>?>.data(null)
        : ref.watch(latestReactivationRequestProvider(user.id));
    final request = latestRequest.valueOrNull;
    final requestStatus = request?['status']?.toString();
    final hasPendingRequest = requestStatus == 'pending';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: AppColors.error,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cuenta desactivada',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu cuenta fue desactivada por un administrador. Puedes enviar una solicitud de revision si consideras que debe reactivarse.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 20),
              _ReasonCard(
                title: 'Motivo de desactivacion',
                text: user?.accountDisabledReason?.trim().isNotEmpty == true
                    ? user!.accountDisabledReason!.trim()
                    : 'No se registro un motivo visible.',
              ),
              if (request != null) ...[
                const SizedBox(height: 14),
                _ReasonCard(
                  title: 'Ultima solicitud: ${_statusLabel(requestStatus)}',
                  text: request['reason']?.toString() ?? '',
                  tone: hasPendingRequest ? AppColors.warning : AppColors.secondary,
                ),
              ],
              const SizedBox(height: 26),
              AppTextField(
                label: 'Justificacion',
                hint: 'Explica por que solicitas la reactivacion...',
                controller: _reasonCtrl,
                maxLines: 4,
                maxLength: Validators.longTextMaxLength,
                inputFormatters: AppInputFormatters.limitedText(
                  Validators.longTextMaxLength,
                ),
                validator: (value) => Validators.textRange(
                  value,
                  minLength: 12,
                  maxLength: Validators.longTextMaxLength,
                  fieldName: 'La justificacion',
                ),
                readOnly: hasPendingRequest || _isSubmitting,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed:
                    hasPendingRequest || _isSubmitting ? null : _pickAttachment,
                icon: Icon(
                  _attachmentBytes == null
                      ? Icons.attach_file_rounded
                      : Icons.check_circle_outline_rounded,
                ),
                label: Text(
                  _attachmentName == null
                      ? 'Adjuntar foto o documento'
                      : _attachmentName!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: hasPendingRequest
                    ? 'Solicitud pendiente'
                    : 'Enviar solicitud de revision',
                onPressed:
                    hasPendingRequest || _isSubmitting ? null : _submit,
                isLoading: _isSubmitting,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Cerrar sesion',
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) context.go(AppRoutes.welcome);
                },
                variant: AppButtonVariant.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'approved' => 'aprobada',
      'rejected' => 'rechazada',
      'cancelled' => 'cancelada',
      _ => 'pendiente',
    };
  }
}

class _ReasonCard extends StatelessWidget {
  final String title;
  final String text;
  final Color tone;

  const _ReasonCard({
    required this.title,
    required this.text,
    this.tone = AppColors.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
