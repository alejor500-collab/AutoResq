-- Prevent dual-role users from receiving, offering, or accepting their own
-- emergency requests as technicians.

DROP POLICY IF EXISTS "asignaciones_insert_tecnico" ON public.asignaciones;
CREATE POLICY "asignaciones_insert_tecnico"
  ON public.asignaciones
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.tecnicos t
      WHERE t.id = tecnico_id
        AND t.usuario_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.id = emergencia_id
        AND e.usuario_id <> auth.uid()
    )
  );

CREATE OR REPLACE FUNCTION public.create_technician_offer(
  p_emergency_id uuid,
  p_offered_amount numeric DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $$
DECLARE
  v_tecnico public.tecnicos%ROWTYPE;
  v_emergency public.emergencias%ROWTYPE;
  v_location public.ubicaciones%ROWTYPE;
  v_lat numeric;
  v_lng numeric;
  v_distance numeric;
  v_eta integer;
  v_offer_id uuid;
BEGIN
  SELECT *
  INTO v_tecnico
  FROM public.tecnicos
  WHERE usuario_id = auth.uid()
    AND estado_verificacion = 'aprobado'
    AND disponible = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Debes estar disponible y aprobado para enviar una oferta.';
  END IF;

  SELECT *
  INTO v_emergency
  FROM public.emergencias
  WHERE id = p_emergency_id
    AND estado = 'pendiente';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Esta solicitud ya no recibe ofertas.';
  END IF;

  IF v_emergency.usuario_id = auth.uid()
     OR v_emergency.usuario_id = v_tecnico.usuario_id THEN
    RAISE EXCEPTION 'No puedes responder tu propia solicitud de emergencia.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.asignaciones a
    JOIN public.emergencias e ON e.id = a.emergencia_id
    WHERE a.tecnico_id = v_tecnico.id
      AND a.estado IN ('aceptada', 'en_ruta', 'atendiendo')
      AND e.estado IN ('pendiente', 'en_proceso', 'atendida')
  ) THEN
    RAISE EXCEPTION 'Ya tienes una emergencia activa.';
  END IF;

  SELECT *
  INTO v_location
  FROM public.ubicaciones
  WHERE emergencia_id = p_emergency_id;

  SELECT COALESCE(ut.latitud, v_tecnico.ubicacion_lat),
         COALESCE(ut.longitud, v_tecnico.ubicacion_lng)
  INTO v_lat, v_lng
  FROM (SELECT 1) s
  LEFT JOIN public.ubicaciones_tecnico ut ON ut.tecnico_id = v_tecnico.id;

  IF v_location.latitud IS NOT NULL
     AND v_location.longitud IS NOT NULL
     AND v_lat IS NOT NULL
     AND v_lng IS NOT NULL THEN
    v_distance := 6371 * acos(
      LEAST(
        1,
        GREATEST(
          -1,
          cos(radians(v_location.latitud::double precision)) *
          cos(radians(v_lat::double precision)) *
          cos(radians((v_lng - v_location.longitud)::double precision)) +
          sin(radians(v_location.latitud::double precision)) *
          sin(radians(v_lat::double precision))
        )
      )
    );
    v_eta := GREATEST(3, CEIL((v_distance / 25) * 60)::integer);
  END IF;

  INSERT INTO public.technician_offers (
    emergencia_id,
    tecnico_id,
    distancia_km,
    eta_minutos,
    monto_ofertado
  )
  VALUES (
    p_emergency_id,
    v_tecnico.id,
    ROUND(v_distance, 2),
    v_eta,
    p_offered_amount
  )
  ON CONFLICT (emergencia_id, tecnico_id)
  DO UPDATE SET
    estado = 'pendiente',
    distancia_km = EXCLUDED.distancia_km,
    eta_minutos = EXCLUDED.eta_minutos,
    monto_ofertado = EXCLUDED.monto_ofertado,
    fecha_oferta = now(),
    fecha_respuesta = NULL
  RETURNING id INTO v_offer_id;

  RETURN v_offer_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_technician_offer(
  p_emergency_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $$
BEGIN
  RETURN public.create_technician_offer(p_emergency_id, NULL);
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_technician_offer(
  p_offer_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $$
DECLARE
  v_offer public.technician_offers%ROWTYPE;
  v_emergency public.emergencias%ROWTYPE;
  v_technician_user_id uuid;
  v_assignment_id uuid;
BEGIN
  SELECT *
  INTO v_offer
  FROM public.technician_offers
  WHERE id = p_offer_id
    AND estado = 'pendiente';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Esta oferta ya no esta disponible.';
  END IF;

  SELECT *
  INTO v_emergency
  FROM public.emergencias
  WHERE id = v_offer.emergencia_id
    AND usuario_id = auth.uid()
    AND estado = 'pendiente';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No puedes aceptar esta oferta.';
  END IF;

  SELECT usuario_id
  INTO v_technician_user_id
  FROM public.tecnicos
  WHERE id = v_offer.tecnico_id;

  IF v_technician_user_id IS NULL
     OR v_technician_user_id = v_emergency.usuario_id THEN
    RAISE EXCEPTION 'No puedes aceptar una oferta de tu propio perfil tecnico.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.asignaciones
    WHERE emergencia_id = v_offer.emergencia_id
      AND estado IN ('aceptada', 'en_ruta', 'atendiendo', 'finalizada')
  ) THEN
    RAISE EXCEPTION 'Esta solicitud ya tiene tecnico asignado.';
  END IF;

  INSERT INTO public.asignaciones (emergencia_id, tecnico_id, estado)
  VALUES (v_offer.emergencia_id, v_offer.tecnico_id, 'aceptada')
  RETURNING id INTO v_assignment_id;

  UPDATE public.emergencias
  SET estado = 'en_proceso'
  WHERE id = v_offer.emergencia_id;

  UPDATE public.technician_offers
  SET estado = CASE WHEN id = p_offer_id THEN 'aceptada' ELSE 'rechazada' END,
      fecha_respuesta = now()
  WHERE emergencia_id = v_offer.emergencia_id
    AND estado = 'pendiente';

  INSERT INTO public.historial (
    emergencia_id,
    actor_id,
    tipo_evento,
    descripcion
  )
  VALUES (
    v_offer.emergencia_id,
    auth.uid(),
    'asignacion',
    'El conductor eligio un tecnico'
  );

  RETURN v_assignment_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_technician_offers_for_driver(
  p_emergency_id uuid
)
RETURNS TABLE (
  id uuid,
  emergencia_id uuid,
  technician_id uuid,
  technician_user_id uuid,
  technician_name text,
  technician_phone text,
  specialty text,
  rating numeric,
  total_services integer,
  distancia_km numeric,
  eta_minutos integer,
  monto_ofertado numeric,
  estado text,
  fecha_oferta timestamp with time zone
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $$
  SELECT
    o.id,
    o.emergencia_id,
    t.id AS technician_id,
    t.usuario_id AS technician_user_id,
    u.nombre AS technician_name,
    u.telefono AS technician_phone,
    t.especialidad AS specialty,
    COALESCE(t.calificacion_promedio, 0) AS rating,
    COALESCE(t.total_servicios, 0)::integer AS total_services,
    o.distancia_km,
    o.eta_minutos,
    o.monto_ofertado,
    o.estado::text,
    o.fecha_oferta
  FROM public.technician_offers o
  JOIN public.tecnicos t ON t.id = o.tecnico_id
  JOIN public.usuarios u ON u.id = t.usuario_id
  JOIN public.emergencias e ON e.id = o.emergencia_id
  WHERE o.emergencia_id = p_emergency_id
    AND t.usuario_id <> e.usuario_id
    AND (
      e.usuario_id = auth.uid()
      OR t.usuario_id = auth.uid()
      OR public.get_rol_usuario(auth.uid()) = 'administrador'
    )
  ORDER BY
    CASE o.estado
      WHEN 'aceptada' THEN 0
      WHEN 'pendiente' THEN 1
      ELSE 2
    END,
    o.distancia_km NULLS LAST,
    o.fecha_oferta;
$$;

REVOKE ALL ON FUNCTION public.create_technician_offer(uuid, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_technician_offer(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.accept_technician_offer(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_technician_offers_for_driver(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_technician_offer(uuid, numeric)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_technician_offer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_technician_offer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_technician_offers_for_driver(uuid)
  TO authenticated;
