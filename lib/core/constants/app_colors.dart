import 'package:flutter/material.dart';

/// Sistema de colores "The Kinetic Calm" — Stitch Design System
abstract class AppColors {
  // ─── Primary (Emergency Red) ──────────────────────────────────────────────
  static const Color primary = Color(0xFFBB020F);
  static const Color primaryContainer = Color(0xFFE02A25);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  static const Color primaryFixed = Color(0xFFFFDAD5);
  static const Color primaryFixedDim = Color(0xFFFFB4AA);

  // ─── Secondary (Navigational meta) ────────────────────────────────────────
  static const Color secondary = Color(0xFF5F5E60);
  static const Color secondaryContainer = Color(0xFFE2DFE1);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF636264);

  // ─── Tertiary (Info / Current step) ───────────────────────────────────────
  static const Color tertiary = Color(0xFF00628B);
  static const Color tertiaryContainer = Color(0xFF007CAF);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFFFCFCFF);
  static const Color tertiaryFixed = Color(0xFFC8E6FF);

  // ─── Surface Architecture (Tonal Layering) ────────────────────────────────
  static const Color surface = Color(0xFFF9F9FB);
  static const Color surfaceDim = Color(0xFFD9DADC);
  static const Color surfaceBright = Color(0xFFF9F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F3F5);
  static const Color surfaceContainer = Color(0xFFEEEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE8E8EA);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E4);
  static const Color surfaceVariant = Color(0xFFE2E2E4);

  // ─── On Surface ───────────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFF1A1C1D);
  static const Color onSurfaceVariant = Color(0xFF5C403C);
  static const Color inverseSurface = Color(0xFF2F3132);
  static const Color inverseOnSurface = Color(0xFFF0F0F2);
  static const Color inversePrimary = Color(0xFFFFB4AA);

  // ─── Background ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF9F9FB);
  static const Color onBackground = Color(0xFF1A1C1D);

  // ─── Error ────────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ─── Outline ──────────────────────────────────────────────────────────────
  static const Color outline = Color(0xFF916F6B);
  static const Color outlineVariant = Color(0xFFE6BDB8);
  static const Color surfaceTint = Color(0xFFBF0811);

  // ─── Semantic aliases (backwards compat) ──────────────────────────────────
  static const Color textPrimary = onSurface;
  static const Color textSecondary = secondary;
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = onPrimary;

  // ─── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFB8C00);
  static const Color info = tertiary;
  static const Color statusPending = Color(0xFFFB8C00);
  static const Color statusInProgress = tertiary;
  static const Color statusAttended = Color(0xFF43A047);
  static const Color statusCompleted = secondary;

  // ─── Map ──────────────────────────────────────────────────────────────────
  static const Color driverMarker = primary;
  static const Color technicianMarker = tertiary;
  static const Color emergencyMarker = Color(0xFFFF6F00);

  // ─── Legacy (keeping for compatibility) ───────────────────────────────────
  static const Color border = surfaceContainerHigh;
  static const Color divider = surfaceContainerLow;
  static const Color shadow = Color(0x0F1A1C1D);

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryContainer, primary],
  );

  static const LinearGradient primaryShadowGradient = LinearGradient(
    colors: [Color(0x40BB020F), Color(0x00BB020F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
