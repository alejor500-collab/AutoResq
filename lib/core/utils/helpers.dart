import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

abstract class AppHelpers {
  // ─── Date formatting ──────────────────────────────────────────────────────
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'es').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm', 'es').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm', 'es').format(date);
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return formatDate(date);
  }

  // ─── Status helpers ───────────────────────────────────────────────────────
  static String statusLabel(String status) {
    switch (status) {
      case AppConstants.statusPending:
        return 'Pendiente';
      case AppConstants.statusInProgress:
        return 'En proceso';
      case AppConstants.statusAttended:
        return 'Atendida';
      case AppConstants.statusCompleted:
        return 'Completada';
      case AppConstants.statusCancelled:
        return 'Cancelada';
      default:
        return status;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case AppConstants.statusPending:
        return AppColors.statusPending;
      case AppConstants.statusInProgress:
        return AppColors.statusInProgress;
      case AppConstants.statusAttended:
        return AppColors.statusAttended;
      case AppConstants.statusCompleted:
        return AppColors.statusCompleted;
      case AppConstants.statusCancelled:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  // ─── Distance formatting ──────────────────────────────────────────────────
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // ─── Rating ───────────────────────────────────────────────────────────────
  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }

  // ─── Role label ───────────────────────────────────────────────────────────
  static String roleLabel(String role) {
    switch (role) {
      case AppConstants.roleDriver:
        return 'Conductor';
      case AppConstants.roleTechnician:
        return 'Técnico';
      case AppConstants.roleAdmin:
        return 'Administrador';
      default:
        return role;
    }
  }

  // ─── SnackBar ─────────────────────────────────────────────────────────────
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    Color bgColor = AppColors.textPrimary;
    if (isError) bgColor = AppColors.error;
    if (isSuccess) bgColor = AppColors.success;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusButton),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Avatar initials ─────────────────────────────────────────────────────
  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
