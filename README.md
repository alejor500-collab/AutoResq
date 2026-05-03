# AutoResQ

> Asistencia en emergencias automotrices — Ecuador

---

## Descripción

AutoResQ es una aplicación móvil Flutter que conecta conductores con problemas vehiculares con técnicos automotrices en Ecuador. Incluye análisis de emergencias con IA, mapa en tiempo real, chat entre conductor y técnico, y sistema de calificaciones.

---

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3.x + Dart 3.x |
| Arquitectura | Clean Architecture + Riverpod |
| Backend | Supabase (Auth + Realtime + PostgreSQL) |
| Mapa | flutter_map + OpenStreetMap + Nominatim |
| IA | OpenAI Responses API via Supabase Edge Functions |
| Navegación | go_router |
| HTTP | dio |
| Fuente | Poppins (Google Fonts) |

---

## Estructura del proyecto

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart       # Paleta de colores
│   │   ├── app_constants.dart    # Constantes globales + placeholders
│   │   └── app_strings.dart      # Textos de la UI
│   ├── errors/
│   │   ├── failures.dart         # Fallas del dominio (Either)
│   │   └── exceptions.dart       # Excepciones de infraestructura
│   ├── network/
│   │   └── dio_client.dart       # Cliente HTTP (Nominatim + servicios cercanos)
│   ├── router/
│   │   └── app_router.dart       # GoRouter + guardias de rol
│   └── utils/
│       ├── helpers.dart          # Formateo, SnackBars, utilidades
│       └── validators.dart       # Validación de formularios
│
├── features/
│   ├── auth/                     # Login, Register, ForgotPassword, Splash
│   ├── emergency/                # Home Conductor/Técnico, crear emergencia,
│   │                             # estado, activo, historial
│   ├── map/                      # Widget de mapa + proveedor de ubicación
│   ├── chat/                     # Chat en tiempo real (Supabase Realtime)
│   ├── ratings/                  # Calificar técnico / conductor
│   ├── profile/                  # Ver y editar perfil
│   └── admin/                    # Dashboard, usuarios, validación, monitor
│
├── shared/
│   ├── providers/
│   │   ├── auth_provider.dart    # AuthNotifier + authStateProvider
│   │   └── role_provider.dart    # Rol activo (con toggle sin re-login)
│   └── widgets/                  # Botones, campos, shimmer, avatares, estrellas
│
└── main.dart                     # Entry point + Supabase init + tema Poppins
```

---

## Pantallas (26)

### Auth / Onboarding
| # | Pantalla | Ruta |
|---|----------|------|
| 1 | SplashScreen | `/` |
| 2 | WelcomeScreen | `/welcome` |
| 3 | LoginScreen | `/login` |
| 4 | RegisterScreen | `/register` |
| 5 | RoleSelectionScreen | `/role-select` |
| 6 | ForgotPasswordScreen | `/forgot-password` |
| 7 | PendingApprovalScreen | `/technician/pending` |

### Conductor
| # | Pantalla | Ruta |
|---|----------|------|
| 8 | DriverHomeScreen | `/driver/home` |
| 9 | CreateEmergencyScreen | `/driver/emergency/create` |
| 10 | EmergencyStatusScreen | `/driver/emergency/status` |
| 11 | DriverChatScreen | `/driver/chat` |
| 12 | RateServiceScreen | `/driver/rate-service` |

### Técnico
| # | Pantalla | Ruta |
|---|----------|------|
| 13 | TechnicianHomeScreen | `/technician/home` |
| 14 | IncomingRequestSheet | bottom sheet |
| 15 | ActiveServiceScreen | `/technician/active-service` |
| 16 | ServiceClosureScreen | `/technician/service-closure` |
| 17 | RateDriverScreen | `/technician/rate-driver` |
| 18 | ServiceCompletedScreen | `/technician/service-completed` |
| 19 | TechnicianChatScreen | `/technician/chat` |

### Compartidas
| # | Pantalla | Ruta |
|---|----------|------|
| 20 | ProfileScreen | `/profile` |
| 21 | EditProfileScreen | `/profile/edit` |
| 22 | EmergencyHistoryScreen | `/history` |

### Admin
| # | Pantalla | Ruta |
|---|----------|------|
| 23 | AdminDashboardScreen | `/admin` |
| 24 | UserManagementScreen | `/admin/users` |
| 25 | TechnicianValidationScreen | `/admin/validate` |
| 26 | EmergencyMonitorScreen | `/admin/monitor` |

---

## Configuración de placeholders

Edita **`lib/core/constants/app_constants.dart`**:

```dart
// ─── Supabase ────────────────────────────────────────────────────────────────
static const String supabaseUrl = 'https://xxxx.supabase.co';
static const String supabaseAnonKey = 'eyJhbGci...';

// OpenAI se configura solo como secreto de Supabase, nunca en Flutter.
```

---

## Configuración de Supabase

El schema completo y actualizado se encuentra en **`supabase/schema.sql`**. Ejecútalo en el editor SQL de tu proyecto Supabase.

### Tablas (11)

| Tabla | Descripción |
|-------|-------------|
| `usuarios` | Perfil de usuarios (conductor / tecnico / admin) |
| `vehiculos` | Vehículos registrados por conductores |
| `tipos_problema` | Catálogo de tipos de emergencia |
| `tecnicos` | Datos de técnicos (especialidad, verificación, disponibilidad) |
| `emergencias` | Solicitudes de asistencia |
| `ubicaciones` | Ubicación de la emergencia |
| `asignaciones` | Asignación técnico ↔ emergencia |
| `mensajes` | Chat en tiempo real |
| `calificaciones` | Calificaciones cruzadas conductor ↔ técnico |
| `historial` | Log de cambios de estado |
| `notificaciones` | Notificaciones internas por evento |

### Realtime habilitado en

`emergencias`, `asignaciones`, `mensajes`, `notificaciones`, `tecnicos`, `ubicaciones_tecnico`

### Trigger de onboarding

`on_auth_user_created` → `crear_perfil_usuario()`: crea fila en `usuarios` automáticamente al registrarse.

### RLS

Activo en todas las tablas con políticas granulares por rol (`conductor` / `tecnico` / `administrador` / `service_role`). Ver detalle en `supabase/schema.sql`.

---

## Instalación

```bash
# 1. Clonar / tener el proyecto Flutter vacío
cd AutoResQ

# 2. Instalar dependencias
flutter pub get

# 3. Configurar placeholders en app_constants.dart

# 4. Ejecutar en dispositivo o emulador
flutter run
```

---

## Permisos requeridos

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>AutoResQ necesita tu ubicación para encontrar técnicos cercanos</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>AutoResQ usa tu ubicación para mostrarte al mapa</string>
```

---

## Diseño

| Token | Valor |
|-------|-------|
| Color primario | `#E53935` (rojo) |
| Color secundario | `#1E88E5` (azul) |
| Fondo | `#FFFFFF` |
| Superficie | `#F5F5F5` |
| Fuente | Poppins |
| Radio tarjetas | 12px |
| Radio botones | 8px |
| Grilla base | 8px |
| Touch target mínimo | 44px |

---

## IA de emergencias

La integracion usa la arquitectura `Flutter -> Supabase Edge Function -> OpenAI Responses API`. Flutter invoca `analyze-emergency` y nunca llama directamente a OpenAI.

Variables/secretos de Supabase:

```bash
supabase secrets set OPENAI_API_KEY="tu_clave_rotada" --project-ref <project-ref>
supabase secrets set OPENAI_MODEL="gpt-5.4-mini" --project-ref <project-ref>
supabase functions deploy analyze-emergency --project-ref <project-ref>
```

Aplica `supabase/migrations/202605020001_add_emergency_ai_analysis.sql` antes de probar. Si el analisis falla, la emergencia se crea igual y queda con `ai_analysis_status = failed`.

---

## Licencia

MIT — Proyecto académico / comercial para Ecuador.
