-- Make in-app emergency notifications actionable and avoid broad false alarms.

CREATE OR REPLACE FUNCTION public.emergency_type_matches_specialty(
  p_specialty text,
  p_emergency_type text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE COALESCE(NULLIF(TRIM(p_specialty), ''), 'general_assistance')
    WHEN 'mechanical_quick' THEN COALESCE(p_emergency_type, 'unknown') IN (
      'Mecanica rapida',
      'Mecánica rápida',
      'minor_mechanic',
      'engine',
      'overheating',
      'brakes'
    )
    WHEN 'battery_electrical' THEN COALESCE(p_emergency_type, 'unknown') IN (
      'Sistema electrico y bateria',
      'Sistema eléctrico y batería',
      'battery_jumpstart',
      'battery',
      'electrical'
    )
    WHEN 'tires_vulcanization' THEN COALESCE(p_emergency_type, 'unknown') IN (
      'Llantas y vulcanizacion',
      'Llantas y vulcanización',
      'tire_change',
      'flat_tire_no_spare',
      'tire'
    )
    WHEN 'tow_truck' THEN COALESCE(p_emergency_type, 'unknown') IN (
      'Grua / remolque',
      'Grúa / remolque',
      'tow_service',
      'accident'
    )
    WHEN 'fuel_delivery' THEN COALESCE(p_emergency_type, 'unknown') IN (
      'Combustible',
      'fuel_delivery',
      'fuel'
    )
    WHEN 'vehicle_locksmith' THEN COALESCE(p_emergency_type, 'unknown') IN (
      'Cerrajeria vehicular',
      'Cerrajería vehicular',
      'locksmith_vehicle',
      'lockout'
    )
    WHEN 'general_assistance' THEN true
    ELSE false
  END;
$$;

CREATE OR REPLACE FUNCTION public.distance_km_between(
  p_lat_a numeric,
  p_lng_a numeric,
  p_lat_b numeric,
  p_lng_b numeric
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_lat_a IS NULL
      OR p_lng_a IS NULL
      OR p_lat_b IS NULL
      OR p_lng_b IS NULL THEN NULL
    ELSE 6371 * acos(
      LEAST(
        1,
        GREATEST(
          -1,
          cos(radians(p_lat_a::double precision)) *
          cos(radians(p_lat_b::double precision)) *
          cos(radians((p_lng_b - p_lng_a)::double precision)) +
          sin(radians(p_lat_a::double precision)) *
          sin(radians(p_lat_b::double precision))
        )
      )
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.notify_new_emergency_in_app()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emergency_type text;
  v_has_specialty_matches boolean;
BEGIN
  v_emergency_type := COALESCE(NEW.ai_emergency_type, NEW.clasificacion_ia, 'unknown');

  SELECT EXISTS (
    SELECT 1
    FROM public.tecnicos t
    WHERE t.estado_verificacion = 'aprobado'
      AND COALESCE(t.disponible, false) = true
      AND t.usuario_id IS DISTINCT FROM NEW.usuario_id
      AND public.emergency_type_matches_specialty(t.especialidad, v_emergency_type)
  )
  INTO v_has_specialty_matches;

  INSERT INTO public.notificaciones (usuario_id, tipo, mensaje, referencia_id)
  SELECT
    ranked.usuario_id,
    'nueva_solicitud',
    'Nueva solicitud disponible cerca de tu zona. Revisa los detalles y envia tu oferta si puedes atenderla.',
    NEW.id
  FROM (
    SELECT
      t.usuario_id,
      public.distance_km_between(
        u.latitud,
        u.longitud,
        COALESCE(ut.latitud, t.ubicacion_lat),
        COALESCE(ut.longitud, t.ubicacion_lng)
      ) AS distance_km
    FROM public.tecnicos t
    LEFT JOIN public.ubicaciones u ON u.emergencia_id = NEW.id
    LEFT JOIN public.ubicaciones_tecnico ut ON ut.tecnico_id = t.id
    WHERE t.estado_verificacion = 'aprobado'
      AND COALESCE(t.disponible, false) = true
      AND t.usuario_id IS DISTINCT FROM NEW.usuario_id
      AND (
        (v_has_specialty_matches AND public.emergency_type_matches_specialty(t.especialidad, v_emergency_type))
        OR NOT v_has_specialty_matches
      )
  ) ranked
  WHERE ranked.usuario_id IS NOT NULL
    AND (
      ranked.distance_km IS NULL
      OR (
        v_emergency_type IN ('Grua / remolque', 'Grúa / remolque', 'tow_service', 'accident')
        AND ranked.distance_km <= 20
      )
      OR (
        v_emergency_type NOT IN ('Grua / remolque', 'Grúa / remolque', 'tow_service', 'accident')
        AND ranked.distance_km <= 15
      )
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.usuario_id = ranked.usuario_id
        AND n.tipo = 'nueva_solicitud'
        AND n.referencia_id = NEW.id
    );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_emergency_in_app ON public.emergencias;
CREATE TRIGGER trg_notify_new_emergency_in_app
AFTER INSERT ON public.emergencias
FOR EACH ROW
WHEN (NEW.estado = 'pendiente')
EXECUTE FUNCTION public.notify_new_emergency_in_app();

CREATE OR REPLACE FUNCTION public.notify_service_finished_in_app()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_technician_name text;
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado AND NEW.estado = 'finalizada' THEN
    SELECT COALESCE(u.nombre, 'Tu tecnico')
    INTO v_technician_name
    FROM public.asignaciones a
    JOIN public.tecnicos t ON t.id = a.tecnico_id
    LEFT JOIN public.usuarios u ON u.id = t.usuario_id
    WHERE a.emergencia_id = NEW.id
    ORDER BY a.fecha_asignacion DESC
    LIMIT 1;

    INSERT INTO public.notificaciones (usuario_id, tipo, mensaje, referencia_id)
    SELECT
      NEW.usuario_id,
      'servicio_finalizado',
      COALESCE(v_technician_name, 'Tu tecnico') ||
        ' marco el servicio como finalizado. Ya puedes calificar la atencion.',
      NEW.id
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.usuario_id = NEW.usuario_id
        AND n.tipo = 'servicio_finalizado'
        AND n.referencia_id = NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_service_finished_in_app ON public.emergencias;
CREATE TRIGGER trg_notify_service_finished_in_app
AFTER UPDATE OF estado ON public.emergencias
FOR EACH ROW
EXECUTE FUNCTION public.notify_service_finished_in_app();
