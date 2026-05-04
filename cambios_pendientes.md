# cambios_pendientes.md — AutoResQ

Archivo de seguimiento del proyecto. Consultar **antes** de hacer cualquier cambio y actualizar **al terminar** cada tarea.

Última optimización del documento: **2026-05-01**

---

## Estado actual resumido

AutoResQ tiene el frontend principal implementado, el backend base en Supabase definido y los flujos admin/técnico más críticos ya corregidos. Firebase fue eliminado del proyecto y la app trabaja con Supabase Auth/Data.

Correcciones antiguas, diagnósticos duplicados y prompts ya resueltos fueron compactados. En este documento quedan detallados únicamente los pendientes reales, riesgos activos o acciones manuales todavía no confirmadas.

---

## Registro de cambios recientes - 2026-05-02

### Tarifario profesional, IA y pricing

- [x] Se implemento el enfoque "IA clasifica, Supabase calcula, Flutter muestra".
- [x] La IA ya no controla precios en el flujo de emergencia; cualquier precio devuelto accidentalmente por IA se ignora a nivel de app.
- [x] Se agregaron modelos y servicio de pricing:
  - `EmergencyAiAnalysisModel`
  - `EmergencyPriceQuote`
  - `EmergencyPricingService`
- [x] Se creo migracion de tarifario con `service_tariffs`, `emergency_price_snapshots` y `emergency_extra_charges`.
- [x] Se agregaron seeds iniciales de tarifas para `tire_change`, `flat_tire_no_spare`, `battery_jumpstart`, `tow_service`, `minor_mechanic`, `locksmith_vehicle` y `fuel_delivery`.
- [x] Grua/remolque usa `pricing_type = distance_based` y requiere destino antes de continuar.
- [x] Calculo de grua implementado con `base_price = 35.00`, `included_km = 5.0`, `price_per_km = 1.25`, `minimum_price = 35.00` y `max_estimated_price = 150.00`.
- [x] Si grua no tiene destino, el flujo queda en `pending_destination` y no permite buscar tecnico.
- [x] Si no existe tarifa activa, se usa fallback diagnostico sin inventar precio.
- [x] Se guarda snapshot del precio al crear la emergencia para que cambios futuros de tarifario no alteren solicitudes ya creadas.
- [x] Se agrego estructura inicial para cargos adicionales pendientes de aprobacion.

### Flujo de reporte de emergencia

- [x] Se reemplazo "Costo base" por tarjeta profesional de tarifa en Paso 3.
- [x] Se elimino texto innecesario como "precio controlado".
- [x] Se ajusto la estetica del Paso 3 para mantener la paleta actual.
- [x] Se corrigieron overflows de layout en filas/botones del flujo.
- [x] Se corrigio el boton "Reportar emergencia" del home conductor.
- [x] Se corrigio el boton "Buscar tecnico cercano" para crear la emergencia y navegar al estado del servicio.
- [x] Se corrigieron acciones de tomar/subir foto en Paso 2.

### Emergencias, solicitudes y estado persistente

- [x] El conductor no puede crear otra emergencia si tiene una activa en `pendiente`, `en_proceso` o `atendida`.
- [x] El tecnico no puede aceptar otra emergencia si tiene asignacion activa en `aceptada`, `en_ruta` o `atendiendo`.
- [x] Se agrego recuperacion persistente de emergencia activa desde Supabase:
  - conductor recarga web/cierra app y vuelve a `Estado del servicio`.
  - tecnico recarga web/cierra app y vuelve a `Servicio activo`.
- [x] Se ajusto la recuperacion de sesiones activas para no redirigir automaticamente al home:
  - conductor ve un aviso de emergencia en curso y puede abrir el servicio.
  - tecnico ve un aviso de servicio en proceso y puede abrir el servicio activo.
- [x] Si conductor intenta crear otra solicitud con una emergencia activa, se muestra ventana de advertencia en lugar de navegar silenciosamente.
- [x] El conductor ahora puede cancelar una solicitud en estado "buscando tecnico" antes de que algun tecnico la acepte; la pantalla muestra "Cancelar solicitud" y confirma que no hay cargo.
- [x] Si tecnico intenta aceptar otra solicitud con un servicio activo, se muestra ventana de advertencia en lugar de navegar silenciosamente.
- [x] Cancelacion actual: no hay recargo implementado. Si no esta asignada se cancela sin cargo; si ya fue aceptada queda cancelada/registrada y la politica de recargos queda pendiente para futuro.
- [x] Se reforzaron validaciones antes de crear emergencia y antes de aceptar solicitud.
- [x] Se filtro la lista de emergencias pendientes para evitar solicitudes viejas residuales.
- [x] Se corrigio relacion ambigua Supabase `tecnicos`/`usuarios` usando joins explicitos.
- [x] Se corrigio que solicitudes se mostraran sin nombre, ubicacion o detalle.
- [x] Se agrego pestaña inferior en rol tecnico para ver solicitudes activas.
- [x] Se corrigio que contador/listado mezclara datos entre cuentas usando consultas por usuario autenticado.

### Estado en tiempo real, mapa y tecnico asignado

- [x] Cuando el tecnico acepta, el conductor ya no debe quedarse indefinidamente en "buscando".
- [x] Se agrego polling/recuperacion robusta para refrescar el estado de emergencia.
- [x] Se agrego flujo de ubicacion viva del tecnico con `ubicaciones_tecnico`.
- [x] Se agrego proveedor `technicianLiveLocationProvider` y upsert de ubicacion del tecnico.
- [x] Se agrego calculo de ruta/ETA hacia el conductor con OSRM y fallback Haversine.
- [x] Se reemplazaron tiempos estimados hardcodeados por ETA basada en distancia/ruta.
- [x] El mapa del conductor muestra ubicacion del tecnico y trazado cuando hay datos.
- [x] Nombre, telefono, especialidad y rating del tecnico asignado se toman de Supabase y no de valores hardcodeados.
- [x] El home tecnico ahora lee `tecnicos.calificacion_promedio` y cuenta asignaciones `finalizada` para mostrar calificacion/servicios reales.
- [x] Se corrigio el boton de llamar usando `url_launcher` con esquema `tel:`.
- [x] El contador de atencion del tecnico ahora inicia desde `fecha_llegada`, guardada al tocar "He llegado", no desde la aceptacion de la solicitud.

### Chat conductor-tecnico

- [x] Se implemento funcionalidad real de chat por asignacion.
- [x] Se corrigio que mensajes enviados por conductor no llegaran al tecnico.
- [x] Se corrigio error rojo en chat del tecnico al abrir la pantalla.
- [x] Se unifico la interfaz del chat tecnico con la del conductor.
- [x] Se agrego estado tipo WhatsApp:
  - un visto: enviado.
  - dos vistos: entregado.
  - dos vistos azules: leido.
- [x] Se corrigio doble visto prematuro.
- [x] Se agrego soporte de avatar/foto de perfil por cadenas de mensajes.
- [x] Se agrego migracion de estado de mensajes con `entregado_at`, `leido_at` y politicas RLS para participantes.
- [x] Se agrego campana superior con contador de mensajes no leidos y aviso in-app cuando entra un mensaje nuevo.
- [x] La pantalla de servicio activo del tecnico ahora tiene menu lateral, campana de chat con aviso de mensajes nuevos y foto de perfil en la cabecera.

### Ubicacion, permisos y perfil

- [x] Se reviso y corrigio el flujo de ubicacion real en Android.
- [x] Se ajusto configuracion Android relacionada con permisos de ubicacion.
- [x] En perfil, la ubicacion editada se muestra como direccion legible cuando existe, no solo coordenadas.
- [x] Se corrigio texto de ubicacion incoherente/hardcodeado mostrado en mapa.

### Roles, tecnico pendiente y aprobacion admin

- [x] Solicitar ser tecnico ya no cambia inmediatamente `usuarios.rol` a `tecnico`.
- [x] Un conductor que solicita ser tecnico queda usable como conductor mientras el administrador revisa.
- [x] Un usuario que se registra como tecnico queda usable como conductor mientras la solicitud esta pendiente.
- [x] El rol tecnico solo se asigna cuando el administrador aprueba la solicitud.
- [x] Si el administrador rechaza, el usuario queda o vuelve como conductor.
- [x] `PendingApprovalScreen` ahora permite "Usar como conductor".
- [x] Router/splash/activeRole ajustados para no bloquear toda la app por validacion tecnica pendiente.
- [x] Se aplico migracion `202605020011_keep_pending_technicians_as_drivers.sql` para corregir usuarios existentes como `tecnico` con solicitud `pendiente` o `rechazada`.

### Calificaciones obligatorias

- [x] Se agrego bloqueo para nuevas emergencias del conductor si tiene calificacion pendiente.
- [x] Se agrego bloqueo para aceptar/atender emergencias del tecnico si tiene calificacion pendiente.
- [x] Se agregaron modales para enviar al usuario a calificar cuando intenta continuar.
- [x] El bloqueo aplica solo sobre servicios finalizados, no cancelados/rechazados/no finalizados.
- [x] Se agrego salida visible para el conductor cuando el servicio queda finalizado:
  - la pantalla de estado muestra tarjeta "Servicio finalizado".
  - permite navegar directamente a calificar al tecnico.
  - el home del conductor avisa de calificacion pendiente al volver a abrir la app.
- [x] Al finalizar el tecnico, el conductor recibe modal obligatorio para calificar el servicio desde la pantalla de estado.
- [x] Se robustecio la calificacion del conductor:
  - resuelve `tecnicos.id` a `usuarios.id` antes de insertar calificacion cuando sea necesario.
  - evita intentar calificar si no existe tecnico asociado al servicio.
- [x] Se corrigio envio de calificacion del tecnico:
  - primero marca asignacion/emergencia como finalizada para cumplir RLS.
  - inserta la calificacion usando el usuario autenticado como `calificador_id`.
  - evita usar el id de perfil tecnico como si fuera id de usuario.
  - muestra el motivo real si falla el insert.
- [x] Persistencia de servicio activo y bloqueo por calificacion trabajan juntos:
  - activo bloquea hasta finalizar.
  - finalizado bloquea hasta calificar.
- [x] El estado de la emergencia selecciona la asignacion mas relevante/reciente para evitar mostrar datos viejos si quedaron asignaciones residuales de pruebas anteriores.
- [x] El contador del servicio tecnico ahora se calcula desde `fecha_asignacion` persistida en Supabase, por lo que no se reinicia al recargar/cerrar/abrir la app.
- [x] Al marcar "He llegado", tambien se actualiza la emergencia a `atendida` para que el conductor no vea el servicio como si el tecnico aun no hubiera llegado.
- [x] Tras calificar/finalizar desde rol tecnico, se limpia la emergencia activa local para que no aparezca de nuevo el aviso de "Servicio en proceso".

### Historial tecnico y chats cerrados

- [x] La primera pestaña del rol tecnico ahora muestra historial de solicitudes atendidas/asignadas.
- [x] El historial tecnico muestra estado, conductor, fecha, ubicacion y monto cuando existe.
- [x] La pestaña de chat del tecnico ahora muestra historial de chats de servicios asignados, no solo el chat activo.
- [x] Chats de servicios finalizados/cancelados/rechazados quedan disponibles en modo lectura.
- [x] El envio de mensajes se bloquea cuando el servicio ya esta cerrado, tanto para tecnico como para conductor.

### Supabase, RLS y migraciones aplicadas

- [x] Se aplicaron migraciones con Supabase CLI al project ref `sseqsmgvovppuzktochd`.
- [x] Se corrigio recursion infinita en politicas RLS de `usuarios`.
- [x] Se agregaron politicas para que participantes asignados puedan ver datos necesarios de conductor/tecnico.
- [x] Se agregaron/ajustaron politicas para chat, snapshots, tarifas, extras y visibilidad de asignaciones.
- [x] Se aplico migracion `202605040001_add_assignment_arrival_time.sql` para guardar `asignaciones.fecha_llegada`.
- [x] Se repararon estados de migraciones aplicadas cuando fue necesario.
- [x] Se desplego/ajusto la Edge Function `analyze-emergency`.
- [x] Se configuro `OPENAI_MODEL` para la funcion IA.

### Android, entorno local y ejecucion

- [x] Se guio la ejecucion directa en Android fisico.
- [x] Se resolvio autorizacion ADB del dispositivo.
- [x] Se corrigio `JAVA_HOME` invalido y JDK usado por Gradle/Flutter.
- [x] Se resolvio problema de build CMake/jni relacionado con ruta de usuario con acento usando terminal/ruta adecuada.
- [x] Se explico `INSTALL_FAILED_USER_RESTRICTED` y la habilitacion de instalacion por USB en MIUI.
- [x] Se explico el problema de DWDS/WebSocket en Chrome debug.

### Limpieza Flutter y compatibilidad

- [x] Se corrigio `emergencyNotifierProvider` faltante/import incorrecto.
- [x] Se reemplazaron usos de `withOpacity` por `withValues(alpha: ...)` en archivos tocados.
- [x] Se explico que las franjas amarillo/negro corresponden a `RenderFlex overflow`.
- [x] Se corrigieron overflows relevantes en UI.
- [x] Se ejecuto `flutter analyze` varias veces tras cambios importantes y quedo sin errores.
- [ ] `dart format` sigue presentando timeouts en esta instalacion; cuando aplique, formatear por lotes o desde IDE.

---

## Pendientes activos / posibles errores persistentes

### P0 — Bloqueantes o críticos

- [ ] **P0.1 — Validar credenciales reales en configuración**
  - Revisar `lib/core/constants/app_constants.dart`.
  - Confirmar que no existan placeholders como:
    - `TU_SUPABASE_URL`
    - `TU_SUPABASE_ANON_KEY`
    - secretos de proveedor IA en Flutter
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
- [x] Barra inferior del técnico reorganizada: `HISTORIAL`, `SOLICITUDES`, `INICIO` al centro, `CHAT` y `PERFIL`.
- [x] La ruta `/technician/home` abre por defecto en `INICIO` y se retiró el tab `SERVICIOS` que había quedado sin uso.
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

## Notificaciones y solicitudes en vivo

- [x] `technicianPendingEmergenciesProvider` actualiza automaticamente las solicitudes pendientes del tecnico cada 4 segundos y reutiliza el filtrado por especialidad.
- [x] El home tecnico consume esa lista viva en mapa, contador y pestana de solicitudes; el boton de recargar queda como accion manual secundaria.
- [x] Si entra una nueva emergencia mientras el tecnico esta disponible dentro de la app, se muestra un `MaterialBanner` con acceso a "Ver lista" o "Ver" la solicitud.
- [x] Se reemplazo el `MaterialBanner` global por un banner propio dentro del `Stack` del home tecnico para evitar aserciones de ciclo de vida al recargar/navegar en Flutter Web.
- [x] Los listeners de solicitudes pendientes y sincronizacion push ahora usan `ref.listenManual` con cierre explicito en `dispose`, evitando efectos laterales en `build`.
- [x] Al aceptar una emergencia se invalidan solicitudes pendientes e historial para que la UI refleje el cambio sin recarga manual.
- [x] `PushNotificationService` inicializa OneSignal con `--dart-define=ONESIGNAL_APP_ID=...` y sincroniza el `external_id` con el `usuarios.id` de Supabase.
- [x] Android declara `POST_NOTIFICATIONS` para Android 13+.
- [x] Edge Function `notify-new-emergency` creada y desplegada; crea filas en `notificaciones` y envia push via OneSignal cuando existan `ONESIGNAL_APP_ID` y `ONESIGNAL_REST_API_KEY`.
- [ ] Accion manual en produccion: configurar OneSignal Android/FCM y guardar los secrets `ONESIGNAL_APP_ID`/`ONESIGNAL_REST_API_KEY` en Supabase; correr Flutter con `--dart-define=ONESIGNAL_APP_ID=...`.
- [x] Validacion: `flutter analyze` sin issues y `flutter build web --no-tree-shake-icons` exitoso. `dart format` volvio a exceder el timeout.

## Regla de mantenimiento

Antes de trabajar en cualquier pendiente:

1. Moverlo a “En progreso” si aplica.
2. Ejecutar cambios mínimos sobre rutas específicas.
3. Actualizar este archivo al finalizar.
4. No reabrir errores antiguos salvo evidencia nueva en runtime.
5. Registrar solo pendientes reales, acciones manuales no confirmadas o bugs reproducibles.
