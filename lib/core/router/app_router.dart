import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/pending_approval_screen.dart';
import '../../features/auth/presentation/screens/account_disabled_screen.dart';
import '../../features/emergency/presentation/screens/driver_home_screen.dart';
import '../../features/emergency/presentation/screens/create_emergency_screen.dart';
import '../../features/emergency/presentation/screens/emergency_status_screen.dart';
import '../../features/emergency/presentation/screens/technician_home_screen.dart';
import '../../features/emergency/presentation/screens/active_service_screen.dart';
import '../../features/emergency/presentation/screens/service_closure_screen.dart';
import '../../features/emergency/presentation/screens/service_completed_screen.dart';
import '../../features/emergency/presentation/screens/emergency_history_screen.dart';
import '../../features/chat/presentation/screens/driver_chat_history_screen.dart';
import '../../features/chat/presentation/screens/driver_chat_screen.dart';
import '../../features/chat/presentation/screens/technician_chat_screen.dart';
import '../../features/ratings/presentation/screens/rate_service_screen.dart';
import '../../features/ratings/presentation/screens/rate_driver_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/edit_vehicle_screen.dart';
import '../../features/profile/presentation/screens/payment_methods_screen.dart';
import '../../features/profile/presentation/screens/security_privacy_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_reports_screen.dart';
import '../../features/admin/presentation/screens/user_management_screen.dart';
import '../../features/admin/presentation/screens/technician_validation_screen.dart';
import '../../features/admin/presentation/screens/emergency_monitor_screen.dart';
import '../../shared/providers/auth_provider.dart';

abstract class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String roleSelect = '/role-select';
  static const String accountDisabled = '/account-disabled';

  // Driver
  static const String driverHome = '/driver/home';
  static const String createEmergency = '/driver/emergency/create';
  static const String emergencyStatus = '/driver/emergency/status';
  static const String driverChatHistory = '/driver/chats';
  static const String driverChat = '/driver/chat';
  static const String rateService = '/driver/rate-service';

  // Technician
  static const String technicianHome = '/technician/home';
  static const String technicianPending = '/technician/pending';
  static const String activeService = '/technician/active-service';
  static const String technicianChat = '/technician/chat';
  static const String rateDriver = '/technician/rate-driver';
  static const String serviceClosure = '/technician/service-closure';
  static const String serviceCompleted = '/technician/service-completed';

  // Shared
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String editVehicle = '/profile/vehicle/edit';
  static const String paymentMethods = '/profile/payment-methods';
  static const String securityPrivacy = '/profile/security-privacy';
  static const String emergencyHistory = '/history';

  // Admin
  static const String adminDashboard = '/admin';
  static const String adminReports = '/admin/reports';
  static const String userManagement = '/admin/users';
  static const String technicianValidation = '/admin/validate';
  static const String emergencyMonitor = '/admin/monitor';
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(authStateProvider, (_, __) => notifier.refresh());
  ref.listen(authNotifierProvider, (_, __) => notifier.refresh());
  ref.listen(passwordRecoveryProvider, (_, __) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final authNotifierState = ref.read(authNotifierProvider);
      final isRecovery = ref.read(passwordRecoveryProvider).value == true;
      final user = authNotifierState.valueOrNull ?? authState.valueOrNull;
      final isLoggedIn = user != null;
      final authIsLoading =
          authNotifierState.isLoading || authState.isLoading;
      final path = state.matchedLocation;
      final isSplash = path == AppRoutes.splash;
      final isResetRoute = path == AppRoutes.resetPassword;
      final isAccountDisabledRoute = path == AppRoutes.accountDisabled;
      final isAuthRoute = [
        AppRoutes.welcome,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.roleSelect,
      ].contains(path);
      final isTechnicianRoute = [
        AppRoutes.technicianHome,
        AppRoutes.activeService,
        AppRoutes.technicianChat,
        AppRoutes.rateDriver,
        AppRoutes.serviceClosure,
        AppRoutes.serviceCompleted,
      ].contains(path);
      final isAdminRoute = [
        AppRoutes.adminDashboard,
        AppRoutes.adminReports,
        AppRoutes.userManagement,
        AppRoutes.technicianValidation,
        AppRoutes.emergencyMonitor,
      ].contains(path);

      if (isSplash) return null;

      // Password recovery deep link: go to reset screen regardless of other state
      if (isRecovery && !isResetRoute) return AppRoutes.resetPassword;

      // Reset-password route: allowed when a session exists (recovery grants one)
      if (isResetRoute) return isLoggedIn ? null : AppRoutes.welcome;

      if (authIsLoading && !isLoggedIn) return null;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.welcome;

      if (isLoggedIn && !user.isActive && !isAccountDisabledRoute) {
        return AppRoutes.accountDisabled;
      }

      if (isLoggedIn && user.isActive && isAccountDisabledRoute) {
        if (user.isAdmin) return AppRoutes.adminDashboard;
        if (user.isTechnician && user.isApproved) {
          return AppRoutes.technicianHome;
        }
        return AppRoutes.driverHome;
      }

      if (isLoggedIn && isAdminRoute && !user.isAdmin) {
        if (user.isTechnician && user.isApproved) {
          return AppRoutes.technicianHome;
        }
        return AppRoutes.driverHome;
      }

      // Técnico pendiente: bloqueado en pantalla de espera hasta ser aprobado
      if (isLoggedIn &&
          user.isTechnician &&
          !user.isApproved &&
          (user.verificationStatus == AppConstants.verificationPending ||
              user.verificationStatus == AppConstants.verificationRejected) &&
          isTechnicianRoute) {
        return AppRoutes.technicianPending;
      }

      if (isLoggedIn && isAuthRoute) {
        if (user.isAdmin) return AppRoutes.adminDashboard;
        if (user.isTechnician && user.isApproved) {
          return AppRoutes.technicianHome;
        }
        return AppRoutes.driverHome;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.roleSelect,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) {
          final initialRole = state.extra as int?;
          return RegisterScreen(initialRole: initialRole);
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountDisabled,
        builder: (context, state) => const AccountDisabledScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // ─── Driver ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.driverHome,
        builder: (context, state) {
          final initialTab = state.extra as int?;
          return DriverHomeScreen(initialTab: initialTab ?? 2);
        },
      ),
      GoRoute(
        path: AppRoutes.createEmergency,
        builder: (context, state) => const CreateEmergencyScreen(),
      ),
      GoRoute(
        path: AppRoutes.emergencyStatus,
        builder: (context, state) {
          final emergencyId = state.extra as String? ?? '';
          return EmergencyStatusScreen(emergencyId: emergencyId);
        },
      ),
      GoRoute(
        path: AppRoutes.driverChatHistory,
        builder: (context, state) => const DriverChatHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverChat,
        builder: (context, state) {
          final emergencyId = state.extra as String? ?? '';
          return DriverChatScreen(emergencyId: emergencyId);
        },
      ),
      GoRoute(
        path: AppRoutes.rateService,
        builder: (context, state) {
          final rawArgs = state.extra;
          final args = rawArgs is Map
              ? rawArgs.map(
                  (key, value) => MapEntry(
                    key.toString(),
                    value?.toString() ?? '',
                  ),
                )
              : const <String, String>{};
          return RateServiceScreen(
            emergencyId: args['emergencyId'] ?? '',
            technicianId: args['technicianId'] ?? '',
            technicianName: args['technicianName'] ?? 'Técnico',
          );
        },
      ),

      // ─── Technician ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.technicianPending,
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: AppRoutes.technicianHome,
        builder: (context, state) {
          final initialTab = state.extra as int?;
          return TechnicianHomeScreen(initialTab: initialTab ?? 2);
        },
      ),
      GoRoute(
        path: AppRoutes.activeService,
        builder: (context, state) {
          final emergencyId = state.extra as String? ?? '';
          return ActiveServiceScreen(emergencyId: emergencyId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianChat,
        builder: (context, state) {
          final emergencyId = state.extra as String? ?? '';
          return TechnicianChatScreen(emergencyId: emergencyId);
        },
      ),
      GoRoute(
        path: AppRoutes.rateDriver,
        builder: (context, state) {
          final rawArgs = state.extra;
          final args = rawArgs is Map
              ? Map<String, dynamic>.fromEntries(
                  rawArgs.entries.map(
                    (entry) => MapEntry(
                      entry.key.toString(),
                      entry.value,
                    ),
                  ),
                )
              : const <String, dynamic>{};
          return RateDriverScreen(
            emergencyId: args['emergencyId']?.toString() ?? '',
            asignacionId: args['asignacionId']?.toString(),
            technicianId: args['technicianId']?.toString(),
            driverId: args['driverId']?.toString() ?? '',
            driverName: args['driverName']?.toString() ?? 'Conductor',
            vehicleInfo: args['vehicleInfo']?.toString(),
            duration: args['duration']?.toString(),
            clasificacionIa: args['clasificacionIa']?.toString(),
            amount: args['amount']?.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.serviceClosure,
        builder: (context, state) => const ServiceClosureScreen(),
      ),
      GoRoute(
        path: AppRoutes.serviceCompleted,
        builder: (context, state) {
          final rawArgs = state.extra;
          final args = rawArgs is Map
              ? Map<String, dynamic>.fromEntries(
                  rawArgs.entries.map(
                    (entry) => MapEntry(
                      entry.key.toString(),
                      entry.value,
                    ),
                  ),
                )
              : const <String, dynamic>{};
          return ServiceCompletedScreen(extra: args);
        },
      ),

      // ─── Shared ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.editVehicle,
        builder: (context, state) => const EditVehicleScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentMethods,
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: AppRoutes.securityPrivacy,
        builder: (context, state) => const SecurityPrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.emergencyHistory,
        builder: (context, state) => const EmergencyHistoryScreen(),
      ),

      // ─── Admin ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminReports,
        builder: (context, state) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.userManagement,
        builder: (context, state) => const UserManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.technicianValidation,
        builder: (context, state) => const TechnicianValidationScreen(),
      ),
      GoRoute(
        path: AppRoutes.emergencyMonitor,
        builder: (context, state) => const EmergencyMonitorScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Página no encontrada: ${state.error}'),
      ),
    ),
  );
});
