# cambios_pendientes.md — AutoResQ

Archivo de seguimiento del proyecto. Consultar **antes** de hacer cualquier cambio y actualizar **al terminar** cada tarea.

Última optimización del documento: **2026-05-01**

---

## Estado actual resumido

AutoResQ tiene el frontend principal implementado, el backend base en Supabase definido y los flujos admin/técnico más críticos ya corregidos. Firebase fue eliminado del proyecto y la app trabaja con Supabase Auth/Data.

Correcciones antiguas, diagnósticos duplicados y prompts ya resueltos fueron compactados. En este documento quedan detallados únicamente los pendientes reales, riesgos activos o acciones manuales todavía no confirmadas.

---

## Pendientes activos / posibles errores persistentes

### P0 — Bloqueantes o críticos

- [ ] **P0.1 — Validar credenciales reales en configuración**
  - Revisar `lib/core/constants/app_constants.dart`.
  - Confirmar que no existan placeholders como:
    - `TU_SUPABASE_URL`
    - `TU_SUPABASE_ANON_KEY`
    - `TU_OPENAI_API_KEY`
  - Si existen, reemplazarlos por valores reales o migrar a `flutter_dotenv` / build flavors.
  - Estado: **pendiente de verificación actual**.

- [ ] **P0.2 — Aplicar SQL pendiente en Supabase producción**
  - El código/schema ya fue corregido, pero falta confirmar si se ejecutó manualmente en Supabase Dashboard → SQL Editor.
  - SQL pendiente principal:
    - policy `tecnicos_update_own` con `TO authenticated`, `USING` y `WITH CHECK`.
    - columna `motivo_rechazo text` si aún no existe en producción.
  - Archivos relacionados:
    - `supabase/schema.sql`
    - `lib/features/auth/presentation/screens/register_screen.dart`
    - `lib/features/admin/presentation/providers/admin_provider.dart`
  - Estado: **pendiente hasta confirmar ejecución real en Supabase**.

- [x] **P0.3 — Despliegue y configuración de `send-rejection-email` en producción**
  - Código implementado: `supabase/functions/send-rejection-email/index.ts` (SMTP Gmail).
  - `admin_provider.dart → rejectTechnician()` ya invoca la función tras actualizar DB.
  - Si el correo falla, el rechazo en DB no se revierte (error registrado en `debugPrint`).
  - Secrets requeridos:
    - `SMTP_USER`
    - `SMTP_PASS`
    - `SMTP_HOST`
    - `SMTP_PORT`
    - `MAIL_FROM`
  - Secrets configurados en Supabase para project ref `sseqsmgvovppuzktochd`.
  - Función desplegada con `supabase functions deploy send-rejection-email --project-ref sseqsmgvovppuzktochd`.
  - Estado: **operativo a nivel de configuración/despliegue; pendiente prueba funcional de entrega si se requiere confirmación por bandeja de entrada**.

- [ ] **P0.4 — Deriva entre Supabase producción y `schema.sql`**
  - En Supabase producción existen funciones/triggers de notificación de verificación técnica, pero el documento anterior indica que parte de esa lógica no está reflejada completamente en `supabase/schema.sql`.
  - Revisar y sincronizar:
    - función `notificar_verificacion_tecnico()`
    - trigger `on_tecnico_verificacion_changed`
  - Objetivo:
    - Que `supabase/schema.sql` sea la fuente de verdad del backend.
  - Estado: **pendiente de consolidación**.

---

### P1 — Funcionalidad MVP pendiente

- [ ] **P1.1 — Notificaciones push**
  - No existe sistema de push notifications.
  - Casos pendientes:
    - Técnico recibe alerta cuando hay emergencia nueva.
    - Conductor recibe alerta cuando un técnico acepta.
  - Opción recomendada:
    - Supabase Edge Functions + OneSignal.
  - Nota:
    - La app no usa Firebase; no usar FCM salvo decisión explícita de reintroducirlo.

- [ ] **P1.2 — Manejo de errores de red**
  - Falta feedback consistente cuando no hay conexión o falla una llamada a Supabase/API.
  - Agregar estados de error en providers Riverpod.
  - Priorizar:
    - auth
    - registro técnico
    - validación admin
    - emergencias
    - tracking de ubicación

- [ ] **P1.3 — Tracking de ubicación del técnico en ruta — Flutter**
  - Backend listo:
    - tabla `ubicaciones_tecnico`
    - RLS
    - Realtime
  - Pendiente de confirmar/implementar en Flutter:
    - `Geolocator` → upsert periódico cuando `asignacion.estado = en_ruta`.
    - conductor suscrito al stream para ver ubicación en tiempo real.
  - Estado: **backend hecho, Flutter pendiente/por verificar**.

---

### P2 — Mejoras post-MVP

- [ ] **P2.1 — Seguridad de credenciales**
  - Migrar credenciales a `.env`, `flutter_dotenv`, build flavors o mecanismo seguro equivalente.

- [ ] **P2.2 — Paginación en historial**
  - `EmergencyHistoryScreen` puede degradarse si hay muchos registros.
  - Agregar paginación o carga incremental.

- [ ] **P2.3 — Tests**
  - El directorio `test/` está vacío o sin cobertura suficiente.
  - Priorizar tests para:
    - auth
    - registro técnico
    - validación admin
    - provider admin
    - navegación por roles

- [ ] **P2.4 — Analytics / monitoreo de errores**
  - Usar Sentry u otra alternativa no Firebase.
  - No usar Crashlytics mientras Firebase esté descartado.

- [ ] **P2.5 — Limpieza de dependencias no usadas**
  - Revisar si `google_sign_in` sigue en `pubspec.yaml` sin uso.
  - Si no se importa en Dart y OAuth ya va por Supabase, eliminar dependencia.

---

## Hecho / cerrado — resumen compacto

### Backend Supabase base

- [x] Base de datos Supabase definida con tablas principales del MVP.
- [x] RLS activado en tablas principales.
- [x] Realtime habilitado para módulos críticos.
- [x] Supabase Auth configurado con Email/Password.
- [x] Trigger `on_auth_user_created` verificado.
- [x] Bucket `avatars` creado y configurado con RLS por `{uid}/`.

### Firebase eliminado

- [x] Eliminada configuración FlutterFire residual.
- [x] Eliminado plugin Gradle `com.google.gms.google-services`.
- [x] Eliminado `google-services.json`.
- [x] Eliminado meta tag web de Google Sign-In asociado al flujo anterior.
- [x] Documentación ajustada para no sugerir Firebase/FCM/Crashlytics.

### Registro y validación de técnicos

- [x] Técnico pendiente ya no debe entrar como aprobado.
- [x] Navegación corregida para técnico pendiente mediante `/technician/pending`.
- [x] `isApproved` ahora considera `estado_verificacion` y `usuarios.activo`.
- [x] Foto de cédula corregida en Flutter:
  - path Storage cambiado de `technicians/{uid}/...` a `{uid}/...`.
  - `url_credencial` se guarda en `tecnicos`.
  - si falla upload/update, no navega al Home.
- [x] Panel admin consulta `url_credencial` explícitamente.
- [x] Admin UI muestra documento de identidad.
- [x] Miniatura de cédula usa `BoxFit.contain`.
- [x] Imagen de cédula se puede abrir en modal con zoom usando `InteractiveViewer`.
- [x] `_TecnicoRequestSheet` extraída de `app_drawer.dart` a `shared/widgets/technician_request_sheet.dart` como `TechnicianRequestSheet` (público).
- [x] `ProfileScreen._AccountSettings` refactorizado a `ConsumerWidget`; usa `tecnicoStatusProvider` en lugar de `user.specialty`/`user.isApproved`.
- [x] `_TechnicianModeItem` en ProfileScreen: pendiente → tile no-tap; aprobado → switch a technicianHome; sin solicitud/rechazado → abre sheet con especialidad + cédula.
- [x] Sheet actualiza `usuarios.rol='tecnico'` solo tras subir cédula correctamente, refresca `authNotifier` y navega a `/technician/pending`.
- [x] Nunca navega a `/technician/home` si `verificationStatus != aprobado`.
- [x] Drawer post-envío también navega a `/technician/pending`.

### Rechazo de técnicos

- [x] Rechazo exige motivo.
- [x] TextField de observaciones obligatorio.
- [x] Motivo combinado se envía a `rejectTechnician()`.
- [x] `motivo_rechazo` agregado al schema.
- [x] `rejectTechnician()` guarda `motivo_rechazo` si recibe valor.
- [x] `AppUser`/`UserModel` exponen `verificationStatus` y `rejectionReason`.
- [x] `_fetchProfile` selecciona `estado_verificacion` y `motivo_rechazo` y los mapea al modelo.
- [x] `PendingApprovalScreen` muestra UI distinta para rechazados: icono error, título "Solicitud rechazada", motivo visible.
- [x] `TecnicoStatus` incluye `motivoRechazo`; query actualizada con `motivo_rechazo`.
- [x] Edge Function `send-rejection-email` migrada de Resend API a SMTP Gmail.
  - [x] `rejectTechnician()` invoca la función; fallo de correo no revierte el rechazo en DB.
  - [x] La función recibe `email`, `nombre` opcional y `motivo`, usa secrets SMTP y escapa HTML del motivo/nombre.
  - [x] `PendingApprovalScreen` agrega botón principal "Enviar nueva solicitud" para técnicos rechazados.
  - [x] Reenvío abre `TechnicianRequestSheet` en modo reenvío, mantiene la misma cuenta y reutiliza la fila `tecnicos` mediante `upsert` por `usuario_id`.
  - [x] Reenvío exige nueva foto de cédula, sube archivo con nombre único `cedula_<timestamp>`, actualiza `url_credencial`, `especialidad`, `estado_verificacion='pendiente'`, `disponible=false` y limpia `motivo_rechazo`.
  - [x] Tras reenviar, se invalida `tecnicoStatusProvider`, se refrescan `authNotifier`/`currentUserProvider` y se mantiene navegación en `/technician/pending`.
  - [x] Despliegue y secrets en producción configurados con Supabase CLI para project ref `sseqsmgvovppuzktochd`.
  - [ ] Verificación local pendiente: `dart format`, `flutter analyze`, `flutter analyze --no-pub` y `dart analyze` no terminaron antes del timeout en esta sesión.

### Gestión de usuarios admin

- [x] `loadUsers()` trae estado de técnico mediante relación con `tecnicos`.
- [x] Corregido cast de `tecnicos` como `Map<String, dynamic>?` por relación uno-a-uno.
- [x] Técnico pendiente ya no aparece como activo verde.
- [x] Tarjetas muestran estado pequeño:
  - Activa
  - Pendiente
  - Deshabilitada
  - Rechazada
- [x] Switch actualiza `usuarios.activo`.
- [x] Switch no aprueba técnicos ni cambia `estado_verificacion`.
- [x] `activo=false` bloquea técnicos aprobados.

### Admin UI

- [x] Dashboard admin implementado.
- [x] Validación de técnicos implementada.
- [x] Monitor de emergencias implementado.
- [x] Gestión de usuarios con navegación admin corregida.
- [x] `AdminBottomNav` creado e integrado.
- [x] Rutas admin verificadas:
  - `/admin`
  - `/admin/users`
  - `/admin/validate`
  - `/admin/monitor`

### UI/UX general

- [x] Welcome screen.
- [x] Role selection con estilo premium.
- [x] Login refactorizado.
- [x] Drawer principal.
- [x] Microinteracciones en botones y campos.
- [x] Ajustes de navegación Apple-style.
- [x] Flujo técnico visual avanzado.
- [x] Pantallas de cierre y finalización de servicio.

### Perfil, vehículos y servicios

- [x] `VehicleProvider` ahora guarda vehículos en Supabase por usuario autenticado y usa caché local separada por cuenta.
- [x] Guardado de vehículo no depende de `upsert(onConflict: usuario_id)`; busca por `usuario_id`, actualiza la fila existente o inserta una nueva.
- [x] Se consolida una sola fila de `vehiculos` por cuenta eliminando duplicados del mismo usuario después de cargar/guardar.
- [x] `EditVehicleScreen` muestra errores específicos de `VehicleSaveException`, incluyendo placa ya registrada en otra cuenta.
- [x] `schema.sql` agrega índice único `idx_vehiculos_usuario_unico` sobre `vehiculos(usuario_id)` para reflejar regla una cuenta → un vehículo.
- [ ] Acción manual en producción: antes de aplicar `idx_vehiculos_usuario_unico`, limpiar posibles duplicados existentes por `usuario_id`.
- [x] Pestaña `SERVICIOS` del home técnico ya no muestra emergencias pendientes; ahora usa `nearbyServicesProvider` como conductor y lista gasolineras, mecánicas, vulcanizadoras, lavadoras y cargadores EV con filtros por categoría.
- [x] En técnico, tocar un servicio cercano cambia al mapa y centra la ubicación seleccionada.
- [x] Interruptor de disponibilidad del técnico persiste `tecnicos.disponible`, lee el valor devuelto por Supabase y refresca `authNotifier`, `currentUserProvider` y `technicianAvailableProvider`.
- [ ] Verificación local pendiente: `dart format` y `dart analyze` volvieron a no terminar antes del timeout en esta sesión.

---

## Errores antiguos marcados como resueltos

Estos errores o diagnósticos ya no deben tratarse como pendientes activos:

- [x] Técnico pendiente entra como aprobado por usar `activo = true`.
- [x] GoRouter manda al Home antes de validar `estado_verificacion`.
- [x] Foto de cédula no llega al panel admin por path Storage incorrecto.
- [x] Admin no consulta `url_credencial`.
- [x] `_CredentialRow` no muestra imagen.
- [x] Cédula se ve recortada sin zoom.
- [x] Motivo de rechazo se descarta silenciosamente.
- [x] Técnico deshabilitado sigue entrando por ignorar `usuarios.activo`.
- [x] Gestión de usuarios no muestra estado de verificación técnica.
- [x] Técnico pendiente/rechazado aparece como “Activa” verde por cast incorrecto de `tecnicos`.
- [x] Switch de usuario no actualiza correctamente `usuarios.activo`.
- [x] Admin sin navegación inferior consistente.
- [x] Rutas admin bloqueadas por redirect.
- [x] Dependencias/configuración Firebase activas en Android/Web.

---

## Historial resumido

| Fecha | Resumen |
|---|---|
| 2026-04-14 / 2026-04-17 | Setup inicial, schema Supabase, RLS, Auth, Realtime, Storage y triggers principales. |
| 2026-04-22 | UI base premium: welcome, login, role selection, drawer, navegación, animaciones y perfil. |
| 2026-04-25 | Flujo técnico avanzado: home técnico, solicitudes entrantes, servicio activo, cierre, rating y servicio completado. |
| 2026-04-27 | Módulo admin: dashboard, bottom nav, gestión de usuarios, validación técnicos y monitor de emergencias. |
| 2026-04-30 | Limpieza Firebase y corrección de navegación para técnico pendiente. |
| 2026-05-01 | Correcciones críticas: cédula, estado visual admin, switch de usuarios, rechazo con motivo, zoom de documento, bloqueo por `activo=false`. |
| 2026-05-01 | Propagación de `verificationStatus`/`rejectionReason` desde DB al modelo y UI distinta para técnicos rechazados en `PendingApprovalScreen`. |
| 2026-05-01 | Edge Function `send-rejection-email` creada e invocada desde `rejectTechnician()`; fallo de correo no revierte el rechazo. |
| 2026-05-01 | ProfileScreen usa `tecnicoStatusProvider`; sheet extraída a widget compartido; rol actualizado en DB solo tras cédula exitosa; navega a `/technician/pending`. |
| 2026-05-01 | Reenvío de solicitud para técnicos rechazados: nueva cédula obligatoria, limpieza de `motivo_rechazo`, estado vuelve a `pendiente` y la app permanece en `/technician/pending`. |
| 2026-05-01 | Vehículo por cuenta robustecido en Supabase/caché, servicios cercanos habilitados en rol técnico y disponibilidad técnica sincronizada con `tecnicos.disponible`. |
| 2026-05-01 | `send-rejection-email` migrada a SMTP Gmail, secrets `SMTP_*`/`MAIL_FROM` configurados y función desplegada en Supabase. |

---

## Regla de mantenimiento

Antes de trabajar en cualquier pendiente:

1. Moverlo a “En progreso” si aplica.
2. Ejecutar cambios mínimos sobre rutas específicas.
3. Actualizar este archivo al finalizar.
4. No reabrir errores antiguos salvo evidencia nueva en runtime.
5. Registrar solo pendientes reales, acciones manuales no confirmadas o bugs reproducibles.
