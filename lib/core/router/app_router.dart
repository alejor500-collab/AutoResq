import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/emergency/presentation/screens/driver_home_screen.dart';
import '../../features/emergency/presentation/screens/create_emergency_screen.dart';
import '../../features/emergency/presentation/screens/emergency_status_screen.dart';
import '../../features/emergency/presentation/screens/technician_home_screen.dart';
import '../../features/emergency/presentation/screens/active_service_screen.dart';
import '../../features/emergency/presentation/screens/emergency_history_screen.dart';
import '../../features/chat/presentation/screens/driver_chat_screen.dart';
import '../../features/chat/presentation/screens/technician_chat_screen.dart';
import '../../features/ratings/presentation/screens/rate_service_screen.dart';
import '../../features/ratings/presentation/screens/rate_driver_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/user_management_screen.dart';
import '../../features/admin/presentation/screens/technician_validation_screen.dart';
import '../../features/admin/presentation/screens/emergency_monitor_screen.dart';
import '../../shared/providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';

abstract class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Driver
  static const String driverHome = '/driver/home';
  static const String createEmergency = '/driver/emergency/create';
  static const String emergencyStatus = '/driver/emergency/status';
  static const String driverChat = '/driver/chat';
  static const String rateService = '/driver/rate-service';

  // Technician
  static const String technicianHome = '/technician/home';
  static const String activeService = '/technician/active-service';
  static const String technicianChat = '/technician/chat';
  static const String rateDriver = '/technician/rate-driver';

  // Shared
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String emergencyHistory = '/history';

  // Admin
  static const String adminDashboard = '/admin';
  static const String userManagement = '/admin/users';
  static const String technicianValidation = '/admin/validate';
  static const String emergencyMonitor = '/admin/monitor';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isAuthRoute = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      ].contains(state.matchedLocation);

      if (isSplash) return null;
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ─── Driver ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.driverHome,
        builder: (context, state) => const DriverHomeScreen(),
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
        path: AppRoutes.driverChat,
        builder: (context, state) {
          final emergencyId = state.extra as String? ?? '';
          return DriverChatScreen(emergencyId: emergencyId);
        },
      ),
      GoRoute(
        path: AppRoutes.rateService,
        builder: (context, state) {
          final args = state.extra as Map<String, String>? ?? {};
          return RateServiceScreen(
            emergencyId: args['emergencyId'] ?? '',
            technicianId: args['technicianId'] ?? '',
            technicianName: args['technicianName'] ?? 'Técnico',
          );
        },
      ),

      // ─── Technician ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.technicianHome,
        builder: (context, state) => const TechnicianHomeScreen(),
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
          final args = state.extra as Map<String, String>? ?? {};
          return RateDriverScreen(
            emergencyId: args['emergencyId'] ?? '',
            driverId: args['driverId'] ?? '',
            driverName: args['driverName'] ?? 'Conductor',
          );
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
        path: AppRoutes.emergencyHistory,
        builder: (context, state) => const EmergencyHistoryScreen(),
      ),

      // ─── Admin ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
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
