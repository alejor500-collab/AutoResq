import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import 'auth_provider.dart';

// Derives the current user's role from auth state
final userRoleProvider = Provider<String?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.value?.role;
});

final isDriverProvider = Provider<bool>((ref) {
  final user = ref.watch(authNotifierProvider).value;
  final activeRole = ref.watch(activeRoleProvider);
  return _canUseRole(user, activeRole) &&
      activeRole == AppConstants.roleDriver;
});

final isTechnicianProvider = Provider<bool>((ref) {
  final user = ref.watch(authNotifierProvider).value;
  final activeRole = ref.watch(activeRoleProvider);
  return _canUseRole(user, activeRole) &&
      activeRole == AppConstants.roleTechnician;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == AppConstants.roleAdmin;
});

// Active role — allows in-session switches without re-login.
// Uses ref.read for initial value so the notifier is NOT re-created when auth
// refreshes. ref.listen keeps it in sync with logout (role → null).
class ActiveRoleNotifier extends StateNotifier<String?> {
  ActiveRoleNotifier(super.initialRole);

  void updateFromAuth(AppUser? previousUser, AppUser? nextUser) {
    if (nextUser == null) {
      state = null;
      return;
    }

    final shouldResetRole = previousUser?.id != nextUser.id ||
        state == null ||
        !_canUseRole(nextUser, state);

    if (shouldResetRole) {
      state = _defaultActiveRole(nextUser);
    }
  }

  void switchTo(String role) => state = role;
}

String? _defaultActiveRole(AppUser? user) {
  if (user == null) return null;
  if (user.isAdmin) return AppConstants.roleAdmin;
  if (user.isTechnician && user.isApproved) return AppConstants.roleTechnician;
  return AppConstants.roleDriver;
}

bool _canUseRole(AppUser? user, String? role) {
  if (user == null || role == null) return false;
  if (user.isAdmin) return role == AppConstants.roleAdmin;
  if (role == AppConstants.roleDriver) return true;
  if (role == AppConstants.roleTechnician) {
    return user.isTechnician && user.isApproved;
  }
  return false;
}

final activeRoleProvider =
    StateNotifierProvider<ActiveRoleNotifier, String?>((ref) {
  final notifier = ActiveRoleNotifier(
    _defaultActiveRole(ref.read(authNotifierProvider).value),
  );
  // Sync on logout/login without re-creating the notifier
  ref.listen(authNotifierProvider, (previous, next) {
    notifier.updateFromAuth(previous?.valueOrNull, next.valueOrNull);
  });
  return notifier;
});

// Technician availability toggle — persists across navigation
final technicianAvailableProvider = StateProvider<bool>((ref) => false);
