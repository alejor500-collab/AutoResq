-- =============================================================================
-- AutoResQ — Schema Principal
-- Proyecto ESPOCH 2026
-- Ejecutar en: Supabase SQL Editor
-- =============================================================================

BEGIN;

-- =============================================================================
-- SECCIÓN 1: EXTENSIONES
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- para búsquedas de texto futuras


-- =============================================================================
-- SECCIÓN 2: TABLAS
-- =============================================================================

-- -------------------------------------
-- 2.1 usuarios
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.usuarios (
    id           uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre       varchar(100) NOT NULL,
    email        varchar(150) NOT NULL UNIQUE,
    telefono     varchar(20),
    rol          varchar(20)  NOT NULL DEFAULT 'conductor'
                     CHECK (rol IN ('conductor', 'tecnico', 'administrador')),
    activo       boolean NOT NULL DEFAULT true,
    avatar_url   text,
    creado_en    timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.usuarios IS
    'Extiende auth.users con datos de perfil y rol de la aplicación.';

-- -------------------------------------
-- 2.2 vehiculos
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.vehiculos (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id   uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    marca        varchar(50) NOT NULL,
    modelo       varchar(50) NOT NULL,
    anio         int  NOT NULL,
    placa        varchar(20) NOT NULL UNIQUE,
    color        varchar(40)
);

COMMENT ON TABLE public.vehiculos IS
    'Vehículos registrados por los conductores.';

-- -------------------------------------
-- 2.3 tipos_problema
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.tipos_problema (
    id          serial PRIMARY KEY,
    nombre      varchar(50) NOT NULL UNIQUE,
    descripcion text
);

COMMENT ON TABLE public.tipos_problema IS
    'Catálogo de categorías de emergencia automotriz.';

-- -------------------------------------
-- 2.4 tecnicos
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.tecnicos (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id           uuid NOT NULL UNIQUE REFERENCES public.usuarios(id) ON DELETE CASCADE,
    especialidad         varchar(100) NOT NULL,
    disponible           boolean NOT NULL DEFAULT false,
    calificacion_promedio numeric(3,2) DEFAULT 0.00,
    ubicacion_lat        numeric(9,6),
    ubicacion_lng        numeric(9,6),
    estado_verificacion  varchar(20) NOT NULL DEFAULT 'pendiente'
                             CHECK (estado_verificacion IN ('pendiente', 'aprobado', 'rechazado')),
    url_credencial       text,
    verificado_por       uuid REFERENCES public.usuarios(id),
    fecha_verificacion   timestamp with time zone
);

COMMENT ON TABLE public.tecnicos IS
    'Perfil extendido del técnico: disponibilidad, ubicación y estado de verificación.';

-- -------------------------------------
-- 2.5 emergencias
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.emergencias (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id       uuid NOT NULL REFERENCES public.usuarios(id),
    vehiculo_id      uuid REFERENCES public.vehiculos(id),
    tipo_problema_id int  REFERENCES public.tipos_problema(id),
    descripcion      text NOT NULL,
    clasificacion_ia text,
    estado           varchar(50) NOT NULL DEFAULT 'pendiente'
                         CHECK (estado IN ('pendiente', 'en_proceso', 'atendida', 'finalizada', 'cancelada')),
    fecha            timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.emergencias IS
    'Solicitudes de emergencia automotriz creadas por conductores.';

-- -------------------------------------
-- 2.6 ubicaciones
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.ubicaciones (
    id            serial PRIMARY KEY,
    emergencia_id uuid NOT NULL UNIQUE REFERENCES public.emergencias(id) ON DELETE CASCADE,
    latitud       numeric(9,6) NOT NULL,
    longitud      numeric(9,6) NOT NULL,
    direccion     text
);

COMMENT ON TABLE public.ubicaciones IS
    'Coordenadas GPS y dirección invertida (Nominatim) de cada emergencia.';

-- -------------------------------------
-- 2.7 asignaciones
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.asignaciones (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    emergencia_id    uuid NOT NULL REFERENCES public.emergencias(id),
    tecnico_id       uuid NOT NULL REFERENCES public.tecnicos(id),
    fecha_asignacion timestamp with time zone DEFAULT now(),
    estado           varchar(50) NOT NULL DEFAULT 'aceptada'
                         CHECK (estado IN ('aceptada', 'en_ruta', 'atendiendo', 'finalizada', 'rechazada'))
);

COMMENT ON TABLE public.asignaciones IS
    'Relaciona una emergencia con el técnico que la atiende.';

-- -------------------------------------
-- 2.8 mensajes
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.mensajes (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    asignacion_id  uuid NOT NULL REFERENCES public.asignaciones(id) ON DELETE CASCADE,
    remitente_id   uuid NOT NULL REFERENCES public.usuarios(id),
    contenido      text NOT NULL,
    leido          boolean NOT NULL DEFAULT false,
    fecha_envio    timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.mensajes IS
    'Chat en tiempo real entre conductor y técnico dentro de una asignación.';

-- -------------------------------------
-- 2.9 calificaciones
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.calificaciones (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    emergencia_id  uuid NOT NULL REFERENCES public.emergencias(id),
    calificador_id uuid NOT NULL REFERENCES public.usuarios(id),
    calificado_id  uuid NOT NULL REFERENCES public.usuarios(id),
    puntuacion     int  NOT NULL CHECK (puntuacion >= 1 AND puntuacion <= 5),
    comentario     text,
    fecha          timestamp with time zone DEFAULT now(),
    UNIQUE (emergencia_id, calificador_id)
);

COMMENT ON TABLE public.calificaciones IS
    'Calificaciones bidireccionales post-servicio (conductor ↔ técnico).';

-- -------------------------------------
-- 2.10 historial
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.historial (
    id            serial PRIMARY KEY,
    emergencia_id uuid NOT NULL REFERENCES public.emergencias(id) ON DELETE CASCADE,
    actor_id      uuid REFERENCES public.usuarios(id),
    tipo_evento   varchar(50) NOT NULL
                      CHECK (tipo_evento IN (
                          'creacion', 'clasificacion_ia', 'asignacion',
                          'cambio_estado', 'mensaje', 'calificacion',
                          'finalizacion', 'cancelacion'
                      )),
    descripcion   text NOT NULL,
    fecha         timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.historial IS
    'Auditoría de eventos de cada emergencia (creación, cambios de estado, etc.).';

-- -------------------------------------
-- 2.11 notificaciones
-- -------------------------------------
CREATE TABLE IF NOT EXISTS public.notificaciones (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id     uuid NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    tipo           varchar(50) NOT NULL
                       CHECK (tipo IN (
                           'nueva_solicitud', 'solicitud_aceptada', 'tecnico_en_ruta',
                           'servicio_finalizado', 'nueva_calificacion',
                           'verificacion_aprobada', 'verificacion_rechazada'
                       )),
    mensaje        text NOT NULL,
    leida          boolean NOT NULL DEFAULT false,
    referencia_id  uuid,
    fecha          timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.notificaciones IS
    'Notificaciones in-app por usuario (conductor, técnico, admin).';


-- =============================================================================
-- SECCIÓN 3: DATOS SEMILLA
-- =============================================================================

INSERT INTO public.tipos_problema (nombre, descripcion)
VALUES
    ('Mecánico',     'Problemas de motor, frenos, transmisión, suspensión'),
    ('Eléctrico',    'Fallas en sistema eléctrico, sensores, computadora del auto'),
    ('Batería',      'Batería descargada o dañada'),
    ('Llantas',      'Pinchazo, llanta baja, cambio de rueda'),
    ('Combustible',  'Sin combustible o problemas de inyección'),
    ('Otro',         'Emergencia no clasificada')
ON CONFLICT (nombre) DO NOTHING;


-- =============================================================================
-- SECCIÓN 4: ÍNDICES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_emergencias_usuario_id
    ON public.emergencias(usuario_id);

CREATE INDEX IF NOT EXISTS idx_emergencias_estado
    ON public.emergencias(estado);

CREATE INDEX IF NOT EXISTS idx_tecnicos_disponible
    ON public.tecnicos(disponible)
    WHERE disponible = true;

CREATE INDEX IF NOT EXISTS idx_tecnicos_ubicacion
    ON public.tecnicos(ubicacion_lat, ubicacion_lng);

CREATE INDEX IF NOT EXISTS idx_tecnicos_estado_verificacion
    ON public.tecnicos(estado_verificacion);

CREATE INDEX IF NOT EXISTS idx_asignaciones_emergencia_id
    ON public.asignaciones(emergencia_id);

CREATE INDEX IF NOT EXISTS idx_mensajes_asignacion_id
    ON public.mensajes(asignacion_id);

CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_leida
    ON public.notificaciones(usuario_id, leida);

CREATE INDEX IF NOT EXISTS idx_historial_emergencia_id
    ON public.historial(emergencia_id);


-- =============================================================================
-- SECCIÓN 5: REALTIME
-- Habilita publicación de cambios para las tablas que Flutter escucha
-- =============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.emergencias;
ALTER PUBLICATION supabase_realtime ADD TABLE public.asignaciones;
ALTER PUBLICATION supabase_realtime ADD TABLE public.mensajes;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tecnicos;


-- =============================================================================
-- SECCIÓN 6: ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Activa RLS en todas las tablas
ALTER TABLE public.usuarios       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehiculos      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipos_problema ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tecnicos       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergencias    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ubicaciones    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asignaciones   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mensajes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calificaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------
-- usuarios
-- -----------------------------------------------------------------------
CREATE POLICY "usuarios_select_own" ON public.usuarios
    FOR SELECT USING (
        auth.uid() = id
        OR EXISTS (
            SELECT 1 FROM public.usuarios u
            WHERE u.id = auth.uid() AND u.rol = 'administrador'
        )
    );

CREATE POLICY "usuarios_update_own" ON public.usuarios
    FOR UPDATE USING (auth.uid() = id);

-- -----------------------------------------------------------------------
-- vehiculos
-- -----------------------------------------------------------------------
CREATE POLICY "vehiculos_crud_owner" ON public.vehiculos
    FOR ALL USING (usuario_id = auth.uid());

-- Los técnicos pueden ver vehículos de emergencias asignadas a ellos
CREATE POLICY "vehiculos_select_tecnico" ON public.vehiculos
    FOR SELECT USING (
        EXISTS (
            SELECT 1
            FROM public.asignaciones a
            JOIN public.emergencias  e ON e.id = a.emergencia_id
            JOIN public.tecnicos     t ON t.id = a.tecnico_id
            WHERE e.vehiculo_id = public.vehiculos.id
              AND t.usuario_id  = auth.uid()
        )
    );

-- -----------------------------------------------------------------------
-- tipos_problema  (solo lectura para todos los autenticados)
-- -----------------------------------------------------------------------
CREATE POLICY "tipos_problema_select_all" ON public.tipos_problema
    FOR SELECT USING (auth.role() = 'authenticated');

-- -----------------------------------------------------------------------
-- tecnicos
-- -----------------------------------------------------------------------
-- Cualquier autenticado puede leer técnicos aprobados y disponibles
CREATE POLICY "tecnicos_select_aprobados" ON public.tecnicos
    FOR SELECT USING (
        (estado_verificacion = 'aprobado' AND disponible = true)
        OR usuario_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.usuarios u
            WHERE u.id = auth.uid() AND u.rol = 'administrador'
        )
    );

-- El propio técnico puede insertar su perfil al registrarse
CREATE POLICY "tecnicos_insert_own" ON public.tecnicos
    FOR INSERT WITH CHECK (usuario_id = auth.uid());

-- Solo el propio técnico puede editar su perfil
CREATE POLICY "tecnicos_update_own" ON public.tecnicos
    FOR UPDATE USING (usuario_id = auth.uid());

-- Administradores tienen acceso total
CREATE POLICY "tecnicos_admin_all" ON public.tecnicos
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.usuarios u
            WHERE u.id = auth.uid() AND u.rol = 'administrador'
        )
    );

-- -----------------------------------------------------------------------
-- emergencias
-- -----------------------------------------------------------------------
-- Conductor: solo sus propias emergencias
CREATE POLICY "emergencias_select_conductor" ON public.emergencias
    FOR SELECT USING (usuario_id = auth.uid());

-- Conductor: puede crear emergencias
CREATE POLICY "emergencias_insert_conductor" ON public.emergencias
    FOR INSERT WITH CHECK (usuario_id = auth.uid());

-- Conductor: puede cancelar sus emergencias
CREATE POLICY "emergencias_update_conductor" ON public.emergencias
    FOR UPDATE USING (usuario_id = auth.uid());

-- Técnico: ve sus emergencias asignadas + las pendientes (para aceptar)
CREATE POLICY "emergencias_select_tecnico" ON public.emergencias
    FOR SELECT USING (
        estado = 'pendiente'
        OR EXISTS (
            SELECT 1
            FROM public.asignaciones a
            JOIN public.tecnicos     t ON t.id = a.tecnico_id
            WHERE a.emergencia_id = public.emergencias.id
              AND t.usuario_id    = auth.uid()
        )
    );

-- Administrador: ve todas
CREATE POLICY "emergencias_admin_all" ON public.emergencias
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.usuarios u
            WHERE u.id = auth.uid() AND u.rol = 'administrador'
        )
    );

-- -----------------------------------------------------------------------
-- ubicaciones
-- -----------------------------------------------------------------------
CREATE POLICY "ubicaciones_select_participantes" ON public.ubicaciones
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.emergencias e
            WHERE e.id = emergencia_id
              AND (
                  e.usuario_id = auth.uid()
                  OR EXISTS (
                      SELECT 1
                      FROM public.asignaciones a
                      JOIN public.tecnicos     t ON t.id = a.tecnico_id
                      WHERE a.emergencia_id = e.id
                        AND t.usuario_id    = auth.uid()
                  )
              )
        )
    );

CREATE POLICY "ubicaciones_insert_conductor" ON public.ubicaciones
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.emergencias e
            WHERE e.id = emergencia_id AND e.usuario_id = auth.uid()
        )
    );

-- -----------------------------------------------------------------------
-- asignaciones
-- -----------------------------------------------------------------------
-- Conductor e técnico involucrados pueden leer
CREATE POLICY "asignaciones_select_participantes" ON public.asignaciones
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.emergencias e
            WHERE e.id = emergencia_id AND e.usuario_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.tecnicos t
            WHERE t.id = tecnico_id AND t.usuario_id = auth.uid()
        )
    );

-- Solo el técnico puede actualizar el estado
CREATE POLICY "asignaciones_update_tecnico" ON public.asignaciones
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.tecnicos t
            WHERE t.id = tecnico_id AND t.usuario_id = auth.uid()
        )
    );

-- Técnico puede insertar (aceptar emergencia)
CREATE POLICY "asignaciones_insert_tecnico" ON public.asignaciones
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tecnicos t
            WHERE t.id = tecnico_id AND t.usuario_id = auth.uid()
        )
    );

-- -----------------------------------------------------------------------
-- mensajes
-- -----------------------------------------------------------------------
CREATE POLICY "mensajes_participantes" ON public.mensajes
    FOR ALL USING (
        EXISTS (
            SELECT 1
            FROM public.asignaciones a
            JOIN public.emergencias  e ON e.id = a.emergencia_id
            JOIN public.tecnicos     t ON t.id = a.tecnico_id
            WHERE a.id = asignacion_id
              AND (e.usuario_id = auth.uid() OR t.usuario_id = auth.uid())
        )
    );

-- -----------------------------------------------------------------------
-- calificaciones
-- -----------------------------------------------------------------------
CREATE POLICY "calificaciones_select_all" ON public.calificaciones
    FOR SELECT USING (auth.role() = 'authenticated');

-- Solo puede insertar quien participó y no ha calificado aún
CREATE POLICY "calificaciones_insert_participante" ON public.calificaciones
    FOR INSERT WITH CHECK (
        calificador_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.emergencias e
            WHERE e.id = emergencia_id
              AND (
                  e.usuario_id = auth.uid()
                  OR EXISTS (
                      SELECT 1
                      FROM public.asignaciones a
                      JOIN public.tecnicos     t ON t.id = a.tecnico_id
                      WHERE a.emergencia_id = e.id
                        AND t.usuario_id    = auth.uid()
                  )
              )
        )
    );

-- -----------------------------------------------------------------------
-- historial
-- -----------------------------------------------------------------------
-- Solo lectura para participantes de la emergencia
CREATE POLICY "historial_select_participantes" ON public.historial
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.emergencias e
            WHERE e.id = emergencia_id
              AND (
                  e.usuario_id = auth.uid()
                  OR EXISTS (
                      SELECT 1
                      FROM public.asignaciones a
                      JOIN public.tecnicos     t ON t.id = a.tecnico_id
                      WHERE a.emergencia_id = e.id
                        AND t.usuario_id    = auth.uid()
                  )
              )
        )
    );

-- Inserción solo desde service_role (sistema)
CREATE POLICY "historial_insert_service" ON public.historial
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- -----------------------------------------------------------------------
-- notificaciones
-- -----------------------------------------------------------------------
CREATE POLICY "notificaciones_own" ON public.notificaciones
    FOR ALL USING (usuario_id = auth.uid());


-- =============================================================================
-- SECCIÓN 7: FUNCIONES Y TRIGGERS
-- =============================================================================

-- -------------------------------------
-- 7.1 crear_perfil_usuario
-- Trigger en auth.users → inserta en public.usuarios al registrarse
-- -------------------------------------
CREATE OR REPLACE FUNCTION public.crear_perfil_usuario()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.usuarios (id, nombre, email, telefono, rol)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email, '@', 1)),
        NEW.email,
        NEW.raw_user_meta_data->>'telefono',
        COALESCE(NEW.raw_user_meta_data->>'rol', 'conductor')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.crear_perfil_usuario();

-- -------------------------------------
-- 7.2 actualizar_calificacion_promedio
-- Trigger en calificaciones → recalcula promedio del técnico
-- -------------------------------------
CREATE OR REPLACE FUNCTION public.actualizar_calificacion_promedio()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tecnico_usuario_id uuid;
    v_promedio           numeric(3,2);
BEGIN
    -- Obtener el usuario_id del calificado (debe ser técnico)
    SELECT t.id INTO v_tecnico_usuario_id
    FROM public.tecnicos t
    WHERE t.usuario_id = NEW.calificado_id;

    IF v_tecnico_usuario_id IS NULL THEN
        RETURN NEW; -- el calificado no es técnico, no hacer nada
    END IF;

    -- Recalcular promedio
    SELECT ROUND(AVG(puntuacion)::numeric, 2)
    INTO v_promedio
    FROM public.calificaciones
    WHERE calificado_id = NEW.calificado_id;

    UPDATE public.tecnicos
    SET calificacion_promedio = COALESCE(v_promedio, 0.00)
    WHERE usuario_id = NEW.calificado_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_calificacion_inserted ON public.calificaciones;
CREATE TRIGGER on_calificacion_inserted
    AFTER INSERT ON public.calificaciones
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_calificacion_promedio();

-- -------------------------------------
-- 7.3 registrar_historial
-- Trigger en emergencias y asignaciones → audita cambios de estado
-- -------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_historial()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_emergencia_id uuid;
    v_descripcion   text;
BEGIN
    IF TG_TABLE_NAME = 'emergencias' THEN
        v_emergencia_id := NEW.id;
        v_descripcion   := 'Estado de emergencia cambió de "' || OLD.estado || '" a "' || NEW.estado || '"';

        INSERT INTO public.historial (emergencia_id, actor_id, tipo_evento, descripcion)
        VALUES (v_emergencia_id, NEW.usuario_id, 'cambio_estado', v_descripcion);

    ELSIF TG_TABLE_NAME = 'asignaciones' THEN
        v_emergencia_id := NEW.emergencia_id;
        v_descripcion   := 'Estado de asignación cambió de "' || OLD.estado || '" a "' || NEW.estado || '"';

        INSERT INTO public.historial (emergencia_id, actor_id, tipo_evento, descripcion)
        VALUES (v_emergencia_id, NULL, 'cambio_estado', v_descripcion);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_emergencia_estado_changed ON public.emergencias;
CREATE TRIGGER on_emergencia_estado_changed
    AFTER UPDATE OF estado ON public.emergencias
    FOR EACH ROW
    WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
    EXECUTE FUNCTION public.registrar_historial();

DROP TRIGGER IF EXISTS on_asignacion_estado_changed ON public.asignaciones;
CREATE TRIGGER on_asignacion_estado_changed
    AFTER UPDATE OF estado ON public.asignaciones
    FOR EACH ROW
    WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
    EXECUTE FUNCTION public.registrar_historial();

-- -------------------------------------
-- 7.4 actualizado_en  (updated_at automático en usuarios)
-- -------------------------------------
CREATE OR REPLACE FUNCTION public.set_actualizado_en()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.actualizado_en = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_usuarios_updated ON public.usuarios;
CREATE TRIGGER on_usuarios_updated
    BEFORE UPDATE ON public.usuarios
    FOR EACH ROW
    EXECUTE FUNCTION public.set_actualizado_en();


-- =============================================================================
-- FIN DEL SCHEMA
-- =============================================================================

COMMIT;
