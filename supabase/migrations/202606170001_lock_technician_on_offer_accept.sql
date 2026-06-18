-- Prevent a technician from being accepted into more than one active service.
-- The technician row is locked while accepting an offer so concurrent drivers
-- cannot accept stale offers for the same technician.

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
  v_technician_available boolean;
  v_assignment_id uuid;
BEGIN
  SELECT *
  INTO v_offer
  FROM public.technician_offers
  WHERE id = p_offer_id
    AND estado = 'pendiente'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Esta oferta ya no esta disponible.';
  END IF;

  SELECT *
  INTO v_emergency
  FROM public.emergencias
  WHERE id = v_offer.emergencia_id
    AND usuario_id = auth.uid()
    AND estado = 'pendiente'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No puedes aceptar esta oferta.';
  END IF;

  SELECT usuario_id, COALESCE(disponible, false)
  INTO v_technician_user_id, v_technician_available
  FROM public.tecnicos
  WHERE id = v_offer.tecnico_id
  FOR UPDATE;

  IF v_technician_user_id IS NULL
     OR v_technician_user_id = v_emergency.usuario_id THEN
    RAISE EXCEPTION 'No puedes aceptar una oferta de tu propio perfil tecnico.';
  END IF;

  IF NOT v_technician_available THEN
    RAISE EXCEPTION 'Este tecnico ya no esta disponible.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.asignaciones
    WHERE tecnico_id = v_offer.tecnico_id
      AND emergencia_id <> v_offer.emergencia_id
      AND estado IN ('aceptada', 'en_ruta', 'atendiendo')
  ) THEN
    RAISE EXCEPTION 'Este tecnico ya tiene una emergencia activa.';
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

  UPDATE public.tecnicos
  SET disponible = false
  WHERE id = v_offer.tecnico_id;

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

REVOKE ALL ON FUNCTION public.accept_technician_offer(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_technician_offer(uuid) TO authenticated;
