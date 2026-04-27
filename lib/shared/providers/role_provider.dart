import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import 'auth_provider.dart';

// Derives the current user's role from auth state
final userRoleProvider = Provider<String?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.value?.role;
});

final isDriverProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == AppConstants.roleDriver;
});

final isTechnicianProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == AppConstants.roleTechnician;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == AppConstants.roleAdmin;
});

// Active role — allows in-session switches without re-login.
// Uses ref.read for initial value so the notifier is NOT re-created when auth
// refreshes. ref.listen keeps it in sync with logout (role → null).
class ActiveRoleNotifier extends StateNotifier<String?> {
  ActiveRoleNotifier(String? initialRole) : super(initialRole);

  void updateFromAuth(String? role) => state = role;
  void switchTo(String role) => state = role;
}

final activeRoleProvider =
    StateNotifierProvider<ActiveRoleNotifier, String?>((ref) {
  final notifier = ActiveRoleNotifier(ref.read(userRoleProvider));
  // Sync on logout/login without re-creating the notifier
  ref.listen<String?>(userRoleProvider, (_, next) {
    notifier.updateFromAuth(next);
  });
  return notifier;
});

// Technician availability toggle — persists across navigation
final technicianAvailableProvider = StateProvider<bool>((ref) => false);
