abstract class AppStrings {
  // ─── General ───────────────────────────────────────────────────────────────
  static const String appName = 'AutoResQ';
  static const String loading = 'Cargando...';
  static const String retry = 'Reintentar';
  static const String cancel = 'Cancelar';
  static const String confirm = 'Confirmar';
  static const String save = 'Guardar';
  static const String edit = 'Editar';
  static const String delete = 'Eliminar';
  static const String search = 'Buscar';
  static const String filter = 'Filtrar';
  static const String close = 'Cerrar';
  static const String accept = 'Aceptar';
  static const String reject = 'Rechazar';
  static const String back = 'Regresar';
  static const String next = 'Siguiente';
  static const String send = 'Enviar';
  static const String yes = 'Sí';
  static const String no = 'No';
  static const String error = 'Error';
  static const String success = 'Éxito';
  static const String warning = 'Advertencia';
  static const String noData = 'Sin datos disponibles';
  static const String noResults = 'No se encontraron resultados';

  // ─── Auth ──────────────────────────────────────────────────────────────────
  static const String login = 'Iniciar Sesión';
  static const String logout = 'Cerrar Sesión';
  static const String register = 'Registrarse';
  static const String email = 'Correo electrónico';
  static const String password = 'Contraseña';
  static const String confirmPassword = 'Confirmar contraseña';
  static const String forgotPassword = '¿Olvidaste tu contraseña?';
  static const String resetPassword = 'Restablecer contraseña';
  static const String sendResetEmail = 'Enviar correo de recuperación';
  static const String dontHaveAccount = '¿No tienes cuenta?';
  static const String alreadyHaveAccount = '¿Ya tienes cuenta?';
  static const String driver = 'Conductor';
  static const String technician = 'Técnico';
  static const String name = 'Nombre completo';
  static const String phone = 'Teléfono';
  static const String specialty = 'Especialidad';
  static const String certifications = 'Certificaciones';
  static const String experience = 'Años de experiencia';

  // ─── Emergency ─────────────────────────────────────────────────────────────
  static const String requestHelp = 'Solicitar Ayuda';
  static const String describeIssue = 'Describe el problema';
  static const String analyzeWithAI = 'Analizar con IA';
  static const String analyzing = 'Analizando...';
  static const String aiAnalysis = 'Análisis de IA';
  static const String emergencyType = 'Tipo de emergencia';
  static const String suggestion = 'Sugerencia';
  static const String confirmEmergency = 'Confirmar emergencia';
  static const String emergencyCreated = 'Emergencia creada';
  static const String searchingTechnician = 'Buscando técnico...';
  static const String technicianAssigned = 'Técnico asignado';
  static const String technicianOnWay = 'Técnico en camino';

  // ─── Status ────────────────────────────────────────────────────────────────
  static const String pending = 'Pendiente';
  static const String inProgress = 'En proceso';
  static const String attended = 'Atendida';
  static const String completed = 'Completada';
  static const String cancelled = 'Cancelada';

  // ─── Technician ────────────────────────────────────────────────────────────
  static const String available = 'Disponible';
  static const String unavailable = 'No disponible';
  static const String nearbyEmergencies = 'Emergencias cercanas';
  static const String newRequest = 'Nueva solicitud';
  static const String driverInfo = 'Información del conductor';
  static const String problemDescription = 'Descripción del problema';
  static const String distance = 'Distancia';
  static const String driverRating = 'Calificación del conductor';

  // ─── Chat ──────────────────────────────────────────────────────────────────
  static const String chat = 'Chat';
  static const String messagePlaceholder = 'Escribe un mensaje...';
  static const String chatWithTechnician = 'Chat con técnico';
  static const String chatWithDriver = 'Chat con conductor';

  // ─── Ratings ───────────────────────────────────────────────────────────────
  static const String rateService = 'Calificar servicio';
  static const String rateDriver = 'Calificar conductor';
  static const String howWasService = '¿Cómo fue el servicio?';
  static const String leaveReview = 'Deja una reseña (opcional)';
  static const String submitRating = 'Enviar calificación';
  static const String thankYouRating = '¡Gracias por tu calificación!';

  // ─── Profile ───────────────────────────────────────────────────────────────
  static const String profile = 'Perfil';
  static const String editProfile = 'Editar perfil';
  static const String emergencyHistory = 'Historial de emergencias';
  static const String switchRole = 'Cambiar a';
  static const String myRating = 'Mi calificación';
  static const String totalServices = 'Servicios realizados';

  // ─── Admin ─────────────────────────────────────────────────────────────────
  static const String adminPanel = 'Panel de Administración';
  static const String userManagement = 'Gestión de usuarios';
  static const String techValidation = 'Validación de técnicos';
  static const String emergencyMonitor = 'Monitor de emergencias';
  static const String totalUsers = 'Total usuarios';
  static const String activeEmergencies = 'Emergencias activas';
  static const String totalTechnicians = 'Total técnicos';
  static const String pendingValidations = 'Validaciones pendientes';
  static const String approve = 'Aprobar';
  static const String approved = 'Aprobado';
  static const String pendingApproval = 'Pendiente de aprobación';

  // ─── Validation ────────────────────────────────────────────────────────────
  static const String fieldRequired = 'Este campo es obligatorio';
  static const String emailInvalid = 'Ingresa un correo válido';
  static const String passwordTooShort = 'La contraseña debe tener al menos 8 caracteres';
  static const String passwordsNoMatch = 'Las contraseñas no coinciden';
  static const String phoneInvalid = 'Ingresa un número válido (ej: 0991234567)';

  // ─── Errors ────────────────────────────────────────────────────────────────
  static const String errorGeneric = 'Ocurrió un error inesperado';
  static const String errorNetwork = 'Sin conexión a internet';
  static const String errorAuth = 'Error de autenticación';
  static const String errorNotFound = 'No se encontró el recurso';
  static const String errorPermission = 'No tienes permiso para esta acción';
  static const String errorLocation = 'No se pudo obtener tu ubicación';
  static const String errorServer = 'Error del servidor. Intenta más tarde';
}
