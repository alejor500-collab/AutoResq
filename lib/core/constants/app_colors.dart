import 'package:flutter/material.dart';

/// Color-in-Context palette for AutoResQ.
///
/// Blue structures the app and carries trust. Red is reserved for emergency,
/// danger, rejection and destructive actions. Green and orange communicate
/// operational state.
abstract class AppColors {
  static const Color navy = Color(0xFF0B1220);
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryContainer = Color(0xFF1E40AF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFFDBEAFE);
  static const Color primaryFixedDim = Color(0xFFBFDBFE);

  static const Color map = Color(0xFF06B6D4);
  static const Color mapDark = Color(0xFF0E7490);

  static const Color assistance = Color(0xFFF97316);
  static const Color assistanceContainer = Color(0xFFFFEDD5);

  static const Color emergency = Color(0xFFDC2626);
  static const Color emergencyContainer = Color(0xFFFEE2E2);
  static const Color onEmergencyContainer = Color(0xFF991B1B);

  static const Color secondary = Color(0xFF64748B);
  static const Color secondaryContainer = Color(0xFFE2E8F0);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF334155);

  static const Color tertiary = map;
  static const Color tertiaryContainer = Color(0xFFCFFAFE);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF164E63);
  static const Color tertiaryFixed = Color(0xFFCFFAFE);

  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceDim = Color(0xFFE2E8F0);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F5F9);
  static const Color surfaceContainer = Color(0xFFE2E8F0);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0);
  static const Color surfaceContainerHighest = Color(0xFFCBD5E1);
  static const Color surfaceVariant = Color(0xFFE2E8F0);

  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF64748B);
  static const Color inverseSurface = navy;
  static const Color inverseOnSurface = Color(0xFFFFFFFF);
  static const Color inversePrimary = Color(0xFF93C5FD);

  static const Color background = Color(0xFFF8FAFC);
  static const Color onBackground = Color(0xFF0F172A);

  static const Color error = emergency;
  static const Color errorContainer = emergencyContainer;
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = onEmergencyContainer;

  static const Color outline = Color(0xFFE2E8F0);
  static const Color outlineVariant = Color(0xFFE2E8F0);
  static const Color surfaceTint = primary;

  static const Color textPrimary = onSurface;
  static const Color textSecondary = secondary;
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textOnPrimary = onPrimary;

  static const Color success = Color(0xFF16A34A);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color onSuccessContainer = Color(0xFF166534);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF92400E);
  static const Color info = primary;
  static const Color disabled = Color(0xFF94A3B8);
  static const Color disabledContainer = Color(0xFFE2E8F0);
  static const Color statusPending = warning;
  static const Color statusInProgress = primary;
  static const Color statusAttended = success;
  static const Color statusCompleted = success;

  static const Color driverMarker = primary;
  static const Color technicianMarker = map;
  static const Color emergencyMarker = assistance;

  static const Color border = surfaceContainerHigh;
  static const Color divider = surfaceContainerLow;
  static const Color shadow = Color(0x140F172A);
  static const Color scrim = Color(0x700B1220);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryContainer, primary, Color(0xFF60A5FA)],
  );

  static const LinearGradient pageBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      background,
      surfaceContainerLow,
    ],
  );

  static const LinearGradient emergencyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), emergency],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), success],
  );

  static const LinearGradient assistanceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFB923C), assistance],
  );

  static const LinearGradient mapGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mapDark, map],
  );

  static const LinearGradient primaryShadowGradient = LinearGradient(
    colors: [Color(0x332563EB), Color(0x002563EB)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
