import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import 'auth_provider.dart';

// Deriva el rol del usuario actual
final userRoleProvider = Provider<String?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.value?.role;
});

// Indica si el usuario tiene rol conductor
final isDriverProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == AppConstants.roleDriver;
});

// Indica si el usuario tiene rol técnico
final isTechnicianProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == AppConstants.roleTechnician;
});

// Indica si el usuario tiene rol admin
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == AppConstants.roleAdmin;
});

// Rol activo (permite cambio sin re-login)
class ActiveRoleNotifier extends StateNotifier<String?> {
  ActiveRoleNotifier(super.initialRole);

  void switchTo(String role) => state = role;
}

final activeRoleProvider =
    StateNotifierProvider<ActiveRoleNotifier, String?>((ref) {
  final role = ref.watch(userRoleProvider);
  return ActiveRoleNotifier(role);
});
