import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import 'auth_provider.dart';

class TecnicoStatus {
  final String? id;
  final String? estado;
  final String? especialidad;
  final String? motivoRechazo;

  const TecnicoStatus({
    this.id,
    this.estado,
    this.especialidad,
    this.motivoRechazo,
  });

  bool get sinSolicitud => estado == null;
  bool get pendiente => estado == AppConstants.verificationPending;
  bool get aprobado => estado == AppConstants.verificationApproved;
  bool get rechazado => estado == AppConstants.verificationRejected;
}

/// Checks the `tecnicos` table for the current user regardless of their `usuarios.rol`.
/// Used to gate the conductor→técnico role switch behind admin approval.
final tecnicoStatusProvider = FutureProvider.autoDispose<TecnicoStatus>((ref) async {
  final user = ref.watch(authNotifierProvider).value;
  if (user == null) return const TecnicoStatus();

  final supabase = ref.read(supabaseClientProvider);
  final data = await supabase
      .from(AppConstants.tableTecnicos)
      .select('id, estado_verificacion, especialidad, motivo_rechazo')
      .eq('usuario_id', user.id)
      .maybeSingle();

  if (data == null) return const TecnicoStatus();
  return TecnicoStatus(
    id: data['id'] as String?,
    estado: data['estado_verificacion'] as String?,
    especialidad: data['especialidad'] as String?,
    motivoRechazo: data['motivo_rechazo'] as String?,
  );
});
