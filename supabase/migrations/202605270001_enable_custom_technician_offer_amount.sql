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

REVOKE ALL ON FUNCTION public.create_technician_offer(uuid, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_technician_offer(uuid, numeric)
  TO authenticated;
