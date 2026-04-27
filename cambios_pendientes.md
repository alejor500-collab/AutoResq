# cambios_pendientes.md — AutoResQ

Archivo de seguimiento del proyecto. Consultar **antes** de hacer cualquier cambio y actualizar **al terminar** cada tarea.

---

## Estado actual del proyecto

El frontend (21 pantallas Flutter) está implementado. Falta conectar el backend real y cubrir funcionalidades críticas para el MVP.

---

## CRITICO — Sin esto la app no arranca

- [ ] **C1 — Credenciales reales**
  - `lib/core/constants/app_constants.dart` tiene placeholders: `TU_SUPABASE_URL`, `TU_SUPABASE_ANON_KEY`, `TU_OPENAI_API_KEY`
  - Crear proyecto en Supabase → copiar URL y anon key
  - Obtener API key de OpenAI
  - Reemplazar los valores (o migrar a `flutter_dotenv`)

- [x] **C2 — Base de datos Supabase**
  - `supabase/schema.sql` revisado y actualizado (2026-04-15): se agregó columna `activo boolean` en `usuarios`
  - 11 tablas: usuarios, vehiculos, tipos_problema, tecnicos, emergencias, ubicaciones, asignaciones, mensajes, calificaciones, historial, notificaciones
  - 4 triggers: `on_auth_user_created`, `on_calificacion_inserted`, `on_emergencia_estado_changed` / `on_asignacion_estado_changed`, `on_usuarios_updated`
  - RLS activo en todas las tablas con políticas granulares por rol (conductor / técnico / administrador / service_role)
  - Realtime habilitado en: emergencias, asignaciones, mensajes, notificaciones, tecnicos
  - Índices de rendimiento creados
  - Trigger `on_auth_user_created` verificado y funcional (2026-04-15)

- [x] **C3 — Realtime en Supabase**
  - Realtime habilitado en: `emergencias`, `mensajes`, `asignaciones`, `notificaciones`, `tecnicos`, `ubicaciones_tecnico`
  - Verificado via `pg_publication_tables` (2026-04-17)

- [x] **C4 — Supabase Auth**
  - Trigger `on_auth_user_created` → `crear_perfil_usuario` activo y funcional
  - Email/Password habilitado (configurado desde dashboard)
  - Trigger verificado via `pg_trigger` (2026-04-17)

---

## IMPORTANTE — Funcionalidad incompleta (MVP)

- [x] **I1 — Subida de foto de perfil (backend)**
  - Bucket `avatars` creado en Supabase Storage (público, máx 5 MB, JPEG/PNG/WEBP)
  - RLS configurada: cada usuario sube/edita solo dentro de `{uid}/` (2026-04-17)
  - `usuarios.avatar_url` ya existe en la tabla
  - **Pendiente Flutter**: lógica de `image_picker` → `supabase.storage.from('avatars').upload()` → guardar URL

- [ ] **I2 — Notificaciones push**
  - No existe ningun sistema de notificaciones
  - Los tecnicos no reciben alerta cuando hay emergencia nueva
  - Los conductores no reciben alerta cuando un tecnico acepta
  - Opciones: Firebase Cloud Messaging (FCM) o Supabase Edge Functions + OneSignal

- [x] **I3 — Tracking de ubicacion del tecnico en ruta (backend)**
  - Tabla `ubicaciones_tecnico` creada con índice único por `tecnico_id` (upsert)
  - RLS: técnico actualiza su propia ubicación; conductor la ve si tiene asignación activa
  - Añadida a `supabase_realtime` para streaming en tiempo real (2026-04-17)
  - **Pendiente Flutter**: `Geolocator` → upsert cada ~5s cuando `asignacion.estado = en_ruta` → conductor subscribe al stream

- [x] **I4 — Flujo de validacion de tecnicos (Admin) (backend)**
  - `tecnicos.estado_verificacion` ya soporta: `pendiente` / `aprobado` / `rechazado`
  - RLS `tecnicos_admin_all` permite al admin hacer UPDATE directo
  - Trigger `on_tecnico_verificacion_changed` → `notificar_verificacion_tecnico()`: inserta notificación `verificacion_aprobada` / `verificacion_rechazada` automáticamente (2026-04-17)
  - **Pendiente Flutter**: `TechnicianValidationScreen` debe hacer `update({'estado_verificacion': 'aprobado', 'verificado_por': uid, 'fecha_verificacion': now})`

- [ ] **I5 — Manejo de errores de red**
  - Falta feedback visual cuando no hay conexion o falla una llamada a API
  - Agregar estados de error en los providers de Riverpod

---

## MEJORAS — Post-MVP

- [ ] **M1 — Seguridad de credenciales** — Migrar a `flutter_dotenv` o build flavors
- [ ] **M2 — Paginacion en historial** — `EmergencyHistoryScreen` puede ser lenta con muchos registros
- [ ] **M3 — Tests** — El directorio `test/` esta vacio
- [ ] **M4 — Analytics/Crashlytics** — Firebase Crashlytics o Sentry para produccion

---

## Historial de cambios completados

| Fecha | Tarea | Descripcion |
|-------|-------|-------------|
| 2026-04-25 | UI rol Técnico — Flujo completo (7 archivos) | **(1) bottom_nav_bar.dart**: `_technicianItems` ampliado de 3 a 4 tabs (INICIO / HISTORIAL / SERVICIOS / PERFIL). **(2) technician_home_screen.dart**: reescritura completa — `GlassAppBar` con avatar + dot online + nombre + campana; `_TechnicianMiniCard` con toggle de disponibilidad (actualiza Supabase `tableTecnicos`); `_VerificationChip`; mapa `AppMapWidget` + markers de emergencias; `AppBottomNavBar(isTechnician: true)` con nav a `emergencyHistory` (tab 1) y `profile` (tab 3). **(3) incoming_request_sheet.dart**: convertido a `ConsumerStatefulWidget`; timer regresivo 30→0 s con auto-cierre; carga `calificacion_promedio` y `total_servicios` del conductor desde Supabase; `_TimerChip` ámbar; `_AiClassificationChip` (rojo mecánica / azul eléctrica / gris otros); al Aceptar → `context.push(activeService, extra: emergency.id)`. **(4) active_service_screen.dart**: subestado local `StateProvider.autoDispose<String>` (EN RUTA / ATENDIENDO); map flex 3:2 ↔ 2:3; `_StatusFloatingChip` pill; `_EnRoutePanel` (Llamar + Chat + He llegado → UPDATE asignacion → cambia substate); `_AttendingPanel` (title + timer mm:ss + Chat + Finalizar → `pushReplacement(serviceClosure, extra: {emergencyId, asignacionId, technicianId, driverId, driverName, clasificacionIa, duration})`). **(5) service_closure_screen.dart** (nuevo): lee extra via `GoRouterState.of(context)`; AppBar "Cerrar Servicio"; check verde 72px; resumen card (avatar conductor, grid vehículo+tiempo, StatusChip clasificación); input monto con `FilteringTextInputFormatter.digitsOnly` y prefijo `$`; botón → `push(rateDriver, extra: {..., vehicleInfo, duration, clasificacionIa, amount})`. **(6) rate_driver_screen.dart**: constructor ampliado con `asignacionId`, `technicianId`, `vehicleInfo`, `duration`, `clasificacionIa`, `amount`; `_runCompletionUpdates()` hace UPDATE `tableAsignaciones(estado=finalizada)` + UPDATE `tableEmergencias(estado=completada)` + UPDATE `tableTecnicos(disponible=true)`; `_submit` INSERT `tableCalificaciones` → completion → `go(serviceCompleted, extra: _resumenParams(techRating: _stars))`; `_skip` solo completion → `go(serviceCompleted)`; `InteractiveStarRating(size:44)`; `TextButton("Omitir por ahora")`. **(7) service_completed_screen.dart** (nuevo): pantalla éxito sin nav; ícono 80px verde; card con acento verde 4px; secciones CLIENTE / TIPO DE FALLA + TIEMPO TOTAL / MONTO / CALIFICACIONES; `techRating > 0` → `StarRating` / else "Omitida"; "Pendiente de calificación del conductor"; `AppButton → context.go(technicianHome)`. **(8) app_router.dart**: constantes `serviceClosure` y `serviceCompleted` ya presentes; imports y GoRoutes para ambas pantallas ya presentes; `rateDriver` usa `Map<String, dynamic>`. |
| 2026-04-22 | Fix + Animaciones Batch 3 | (1) DriverHomeScreen: Glass AppBar movido al último hijo del Stack (fix z-order, botones menu/perfil ahora responden). (2) TechnicianHomeScreen: SafeArea top bar movido al último hijo del Stack (fix defensivo). (3) AppDrawer: sección ADMINISTRACIÓN agregada para rol admin (Dashboard, Usuarios, Validar Técnicos, Monitor). (4) AppButton: animación de presión con AnimatedScale — scale 0.96 (easeOutQuart 100ms) al presionar, scale 1.0 (elasticOut 220ms) al soltar. (5) AppTextField: micro-interacciones — shake con Curves.elasticOut al error, fillColor verde/rojo por estado, label con ✓ verde cuando válido. |
| 2026-04-22 | UI/UX Premium Batch 2 | (1) RoleSelectionScreen: Curves.easeOutQuart + AnimatedContainer border feedback. (2) LoginScreen: AnimatedSwitcher revela form email/pass tras "Ingresar con Email" con AnimatedSize + easeOutQuart. (3) DioClient: queryNearbyServices() via Overpass API (radio 5km, amenity=fuel + shop=car_repair). (4) NearbyServicesProvider + NearbyService model (Haversine). (5) DriverHomeScreen: carrusel horizontal interactivo con datos OSM reales. (6) EditProfileScreen: image_picker + upload a bucket avatars de Supabase + sync en AppBar. (7) RegisterScreen: paso de foto de cédula para técnicos + upload url_credencial. (8) DiagnosticStep: wrapped in SingleChildScrollView. |
| 2026-04-22 | UI — Navegación Apple Style (Task 3) | **Back buttons:** `emergency_status_screen` y `profile_screen` reemplazaron íconos de menú roto por back buttons (`arrow_back_ios_new`) con `InkWell` feedback táctil. `emergency_status_screen` pasa de `context.go(driverHome)` a `context.pop()` y title correcto. **Drawer:** `AppDrawer` creado (`lib/shared/widgets/app_drawer.dart`) con user header, nav items (Inicio / Historial / Perfil) y logout. Integrado en `DriverHomeScreen` y `TechnicianHomeScreen` con `GlobalKey<ScaffoldState>`. Ícono menú wired a `openDrawer()`. **Tactile feedback:** Todos los botones de AppBar usan `Material + InkWell` con `splashColor` y `CircleBorder` para perfil. **activeRoleProvider fix:** eliminado `ref.watch` del factory (evita re-creación del notifier); usa `ref.read` para init y `ref.listen` para sync en logout. **technicianAvailableProvider:** nuevo `StateProvider<bool>` en `role_provider.dart`; `TechnicianHomeScreen` usa el provider en lugar de `_isAvailable` local state (persiste en navegación). |
| 2026-04-22 | UI — RoleSelectionScreen (Onboarding Premium con Hero) | Creada `role_selection_screen.dart`: pantalla de selección de rol con 2 tarjetas (Conductor / Técnico). Implementa ScaleTransition + AnimationController con `Curves.easeInOutCubic` para feedback táctil de presión. Animación Hero en el ícono de cada tarjeta que vuela hacia `RegisterScreen`. Animaciones de entrada escalonadas (FadeTransition + SlideTransition). Paleta: Rojo #E53935 para Conductor, Azul #1E88E5 para Técnico. Ruta `/role-select` agregada al router y al guard de auth. `WelcomeScreen` "Registrarse" ahora apunta a `/role-select`. `RegisterScreen` acepta `initialRole` (int?), inicializa el selector de rol correspondiente, y muestra el Hero landing widget del ícono. |
| 2026-04-22 | UI — WelcomeScreen + refactor LoginScreen | Creada `welcome_screen.dart` con 3 CTAs (Ingresar, Google, Registrarse). `login_screen.dart` refactorizado a formulario puro email/contraseña con back button. Router actualizado: ruta `/welcome` agregada, redirect de usuarios no autenticados apunta a `/welcome`. SplashScreen actualizado al mismo. |
| 2026-04-14 | Setup inicial | Creacion de `cambios_pendientes.md` y memoria del proyecto |
| 2026-04-15 | C2 — Schema DB | Revisión y actualización de `supabase/schema.sql`: campo `activo` añadido a `usuarios`, schema verificado contra spec definitiva |
| 2026-04-15 | Fix — RLS recursión infinita en usuarios | Política `usuarios_select_own` causaba recursión al consultar `usuarios` desde sí misma. Fix: función `get_rol_usuario()` con `SECURITY DEFINER` para leer el rol sin activar RLS. |
| 2026-04-15 | Fix — Registro teléfono + navegación al home | **Teléfono**: trigger `crear_perfil_usuario` ahora incluye `telefono`; metadata de `signUp` corregida a claves `nombre/telefono/rol`. **Home**: `tableProfiles` corregido de `'profiles'` → `'usuarios'`; `_fetchProfile` mapea columnas DB (nombre/telefono/rol) a model; `register()` ya no hace upsert en tabla errónea; se añadió política RLS `tecnicos_insert_own`. ✅ Aplicado en Supabase (2026-04-15) |
| 2026-04-17 | C3 — Realtime verificado | Confirmado via `pg_publication_tables`: 5 tablas activas. `ubicaciones_tecnico` añadida también. |
| 2026-04-17 | C4 — Auth verificado | Trigger `on_auth_user_created` activo. Email/Password habilitado desde dashboard. |
| 2026-04-17 | I1 — Bucket avatars | Bucket `avatars` creado (público, 5MB, img). 4 políticas RLS en `storage.objects` para `{uid}/` path. |
| 2026-04-17 | I3 — ubicaciones_tecnico | Tabla con unique index por `tecnico_id`, RLS granular (técnico escribe, conductor lee si asignación activa), añadida a Realtime. |
| 2026-04-17 | I4 — Trigger verificación técnico | Función `notificar_verificacion_tecnico()` + trigger `on_tecnico_verificacion_changed`: notificación automática al aprobar/rechazar. |

---

> **Regla:** Antes de trabajar en cualquier item, moverlo a "En progreso". Al terminar, marcarlo `[x]` y agregar fila al historial.
