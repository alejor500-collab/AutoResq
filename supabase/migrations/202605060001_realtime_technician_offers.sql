-- Realtime technician offers: driver creates a request, technicians respond,
-- and the driver chooses the technician to assign.

CREATE TABLE IF NOT EXISTS public.technician_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emergencia_id uuid NOT NULL REFERENCES public.emergencias(id) ON DELETE CASCADE,
  tecnico_id uuid NOT NULL REFERENCES public.tecnicos(id) ON DELETE CASCADE,
  estado varchar(20) NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aceptada', 'rechazada', 'cancelada')),
  distancia_km numeric(8,2),
  eta_minutos integer,
  monto_ofertado numeric(10,2),
  mensaje text,
  fecha_oferta timestamp with time zone NOT NULL DEFAULT now(),
  fecha_respuesta timestamp with time zone,
  UNIQUE (emergencia_id, tecnico_id)
);

CREATE INDEX IF NOT EXISTS technician_offers_emergencia_id_idx
  ON public.technician_offers(emergencia_id);

CREATE INDEX IF NOT EXISTS technician_offers_tecnico_id_idx
  ON public.technician_offers(tecnico_id);

ALTER TABLE public.technician_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "technician_offers_select_participants"
  ON public.technician_offers;
CREATE POLICY "technician_offers_select_participants"
  ON public.technician_offers
  FOR SELECT TO authenticated
  USING (
    public.get_rol_usuario(auth.uid()) = 'administrador'
    OR EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.id = technician_offers.emergencia_id
        AND e.usuario_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM public.tecnicos t
      WHERE t.id = technician_offers.tecnico_id
        AND t.usuario_id = auth.uid()
    )
  );

CREATE OR REPLACE FUNCTION public.create_technician_offer(
  p_emergency_id uuid
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
    eta_minutos
  )
  VALUES (
    p_emergency_id,
    v_tecnico.id,
    ROUND(v_distance, 2),
    v_eta
  )
  ON CONFLICT (emergencia_id, tecnico_id)
  DO UPDATE SET
    estado = 'pendiente',
    distancia_km = EXCLUDED.distancia_km,
    eta_minutos = EXCLUDED.eta_minutos,
    fecha_oferta = now(),
    fecha_respuesta = NULL
  RETURNING id INTO v_offer_id;

  RETURN v_offer_id;
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

REVOKE ALL ON FUNCTION public.create_technician_offer(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.accept_technician_offer(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_technician_offers_for_driver(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_technician_offer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_technician_offer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_technician_offers_for_driver(uuid)
  TO authenticated;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.technician_offers;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;
