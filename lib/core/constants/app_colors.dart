import 'package:flutter/material.dart';

/// Color-in-Context palette for AutoResQ.
///
/// Blue structures the app and carries trust. Red is reserved for emergency,
/// danger, rejection and destructive actions. Green and orange communicate
/// operational state.
abstract class AppColors {
  static const Color primary = Color(0xFF0D6EFD);
  static const Color primaryContainer = Color(0xFF0A58CA);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFFEAF2FF);
  static const Color primaryFixedDim = Color(0xFFCFE0FF);

  static const Color emergency = Color(0xFFE53935);
  static const Color emergencyContainer = Color(0xFFFFECE9);
  static const Color onEmergencyContainer = Color(0xFF9E241F);

  static const Color secondary = Color(0xFF5F6F85);
  static const Color secondaryContainer = Color(0xFFE6ECF5);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF314155);

  static const Color tertiary = Color(0xFF14967F);
  static const Color tertiaryContainer = Color(0xFFE4F7F2);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF0D5F51);
  static const Color tertiaryFixed = Color(0xFFE4F7F2);

  static const Color surface = Color(0xFFF6F8FC);
  static const Color surfaceDim = Color(0xFFE9EDF5);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F4FA);
  static const Color surfaceContainer = Color(0xFFE8EEF7);
  static const Color surfaceContainerHigh = Color(0xFFDCE5F0);
  static const Color surfaceContainerHighest = Color(0xFFCFD9E6);
  static const Color surfaceVariant = Color(0xFFE3EAF4);

  static const Color onSurface = Color(0xFF162033);
  static const Color onSurfaceVariant = Color(0xFF6D7C91);
  static const Color inverseSurface = Color(0xFF162033);
  static const Color inverseOnSurface = Color(0xFFFFFFFF);
  static const Color inversePrimary = Color(0xFF8EBCFF);

  static const Color background = Color(0xFFF4F7FB);
  static const Color onBackground = Color(0xFF162033);

  static const Color error = emergency;
  static const Color errorContainer = emergencyContainer;
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = onEmergencyContainer;

  static const Color outline = Color(0xFFB7C3D4);
  static const Color outlineVariant = Color(0xFFD8E0EB);
  static const Color surfaceTint = primary;

  static const Color textPrimary = onSurface;
  static const Color textSecondary = secondary;
  static const Color textHint = Color(0xFF94A0B2);
  static const Color textOnPrimary = onPrimary;

  static const Color success = Color(0xFF1E9E62);
  static const Color successContainer = Color(0xFFE6F7EF);
  static const Color onSuccessContainer = Color(0xFF0D6A40);
  static const Color warning = Color(0xFFF2992E);
  static const Color warningContainer = Color(0xFFFFF1DE);
  static const Color onWarningContainer = Color(0xFF9A5700);
  static const Color info = primary;
  static const Color disabled = Color(0xFF9AA6B7);
  static const Color disabledContainer = Color(0xFFE8EDF4);
  static const Color statusPending = warning;
  static const Color statusInProgress = primary;
  static const Color statusAttended = success;
  static const Color statusCompleted = success;

  static const Color driverMarker = primary;
  static const Color technicianMarker = success;
  static const Color emergencyMarker = emergency;

  static const Color border = surfaceContainerHigh;
  static const Color divider = surfaceContainerLow;
  static const Color shadow = Color(0x14162033);
  static const Color scrim = Color(0x70162033);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryContainer, primary, Color(0xFF4D9BFF)],
  );

  static const LinearGradient pageBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8FBFF),
      Color(0xFFF4F7FB),
      Color(0xFFEEF3F9),
    ],
  );

  static const LinearGradient emergencyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9544F), Color(0xFFD63A36)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF29B36F), Color(0xFF188A55)],
  );

  static const LinearGradient primaryShadowGradient = LinearGradient(
    colors: [Color(0x330D6EFD), Color(0x000D6EFD)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
