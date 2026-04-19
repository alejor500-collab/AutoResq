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
