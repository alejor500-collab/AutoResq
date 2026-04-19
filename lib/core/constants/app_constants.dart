abstract class AppConstants {
  // ─── Supabase ──────────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://sseqsmgvovppuzktochd.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzZXFzbWd2b3ZwcHV6a3RvY2hkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTU2MDUsImV4cCI6MjA5MTgzMTYwNX0.NZeeBH5Djmm6TO4ZNK2Hda-TbYaVWTrDzqf9LJcF37Y';

  // ─── OpenAI ────────────────────────────────────────────────────────────────
  static const String openAiApiKey = 'TU_OPENAI_API_KEY';
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String openAiModel = 'gpt-4o-mini';

  // ─── App ───────────────────────────────────────────────────────────────────
  static const String appName = 'AutoResQ';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Asistencia de confianza en Riobamba';

  // ─── Roles ─────────────────────────────────────────────────────────────────
  static const String roleDriver = 'conductor';
  static const String roleTechnician = 'tecnico';
  static const String roleAdmin = 'administrador';

  // ─── Emergency Status ──────────────────────────────────────────────────────
  static const String statusPending = 'pendiente';
  static const String statusInProgress = 'en_proceso';
  static const String statusAttended = 'atendida';
  static const String statusCompleted = 'finalizada';
  static const String statusCancelled = 'cancelada';

  // ─── Assignment Status ─────────────────────────────────────────────────────
  static const String assignAccepted = 'aceptada';
  static const String assignEnRoute = 'en_ruta';
  static const String assignAttending = 'atendiendo';
  static const String assignFinished = 'finalizada';
  static const String assignRejected = 'rechazada';

  // ─── Technician Verification ───────────────────────────────────────────────
  static const String verificationPending = 'pendiente';
  static const String verificationApproved = 'aprobado';
  static const String verificationRejected = 'rechazado';

  // ─── Map ───────────────────────────────────────────────────────────────────
  static const double defaultLat = -1.6635;  // Riobamba, Ecuador
  static const double defaultLng = -78.6538;
  static const double defaultZoom = 14.0;
  static const String nominatimUrl = 'https://nominatim.openstreetmap.org';
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // ─── Storage Keys ──────────────────────────────────────────────────────────
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserRole = 'user_role';
  static const String keyUserId = 'user_id';

  // ─── Supabase Tables (nombres en español, coinciden con el schema) ─────
  static const String tableUsuarios = 'usuarios';
  static const String tableTecnicos = 'tecnicos';
  static const String tableVehiculos = 'vehiculos';
  static const String tableTiposProblema = 'tipos_problema';
  static const String tableEmergencias = 'emergencias';
  static const String tableUbicaciones = 'ubicaciones';
  static const String tableAsignaciones = 'asignaciones';
  static const String tableMensajes = 'mensajes';
  static const String tableCalificaciones = 'calificaciones';
  static const String tableHistorial = 'historial';
  static const String tableNotificaciones = 'notificaciones';
  static const String tableUbicacionesTecnico = 'ubicaciones_tecnico';

  // ─── Backwards compat aliases ──────────────────────────────────────────────
  static const String tableProfiles = tableUsuarios;

  // ─── Supabase Storage ──────────────────────────────────────────────────────
  static const String bucketAvatars = 'avatars';

  // ─── UI — "The Kinetic Calm" Design System ─────────────────────────────────
  static const double borderRadiusCard = 16.0;      // rounded-lg
  static const double borderRadiusButton = 9999.0;  // pill/full
  static const double borderRadiusInput = 24.0;     // rounded-2xl
  static const double borderRadiusMd = 16.0;
  static const double borderRadiusLg = 32.0;
  static const double borderRadiusXl = 48.0;
  static const double minTouchTarget = 56.0;        // h-14
  static const double gridUnit = 8.0;
  static const double pagePadding = 24.0;
  static const double bottomNavHeight = 80.0;
  static const double appBarHeight = 64.0;

  // ─── Animation ─────────────────────────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration splashDuration = Duration(seconds: 3);
}
