-- Keep pending emergency re-delivery aligned with the app and edge function.
-- If there are no specialty matches for a technician, fall back to any
-- compatible pending emergency within range instead of sending nothing.
-- Also re-run the notification sync when specialty or stored coordinates change.

CREATE OR REPLACE FUNCTION public.notify_pending_emergencies_for_technician(
  p_technician_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_technician public.tecnicos%ROWTYPE;
  v_has_specialty_matches boolean;
BEGIN
  SELECT *
  INTO v_technician
  FROM public.tecnicos
  WHERE id = p_technician_id
    AND estado_verificacion = 'aprobado'
    AND COALESCE(disponible, false) = true;

  IF NOT FOUND OR v_technician.usuario_id IS NULL THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.emergencias e
    WHERE e.estado = 'pendiente'
      AND e.usuario_id IS DISTINCT FROM v_technician.usuario_id
      AND public.emergency_type_matches_specialty(
        v_technician.especialidad,
        COALESCE(e.ai_emergency_type, e.clasificacion_ia, 'unknown')
      )
  )
  INTO v_has_specialty_matches;

  INSERT INTO public.notificaciones (usuario_id, tipo, mensaje, referencia_id)
  SELECT
    v_technician.usuario_id,
    'nueva_solicitud',
    'Nueva solicitud disponible. Revisa los detalles y envia tu oferta si puedes atenderla.',
    e.id
  FROM public.emergencias e
  LEFT JOIN public.ubicaciones u ON u.emergencia_id = e.id
  LEFT JOIN public.ubicaciones_tecnico ut
    ON ut.tecnico_id = v_technician.id
  WHERE e.estado = 'pendiente'
    AND e.usuario_id IS DISTINCT FROM v_technician.usuario_id
    AND (
      (v_has_specialty_matches AND public.emergency_type_matches_specialty(
        v_technician.especialidad,
        COALESCE(e.ai_emergency_type, e.clasificacion_ia, 'unknown')
      ))
      OR NOT v_has_specialty_matches
    )
    AND (
      public.distance_km_between(
        u.latitud,
        u.longitud,
        COALESCE(ut.latitud, v_technician.ubicacion_lat),
        COALESCE(ut.longitud, v_technician.ubicacion_lng)
      ) IS NULL
      OR public.distance_km_between(
        u.latitud,
        u.longitud,
        COALESCE(ut.latitud, v_technician.ubicacion_lat),
        COALESCE(ut.longitud, v_technician.ubicacion_lng)
      ) <= CASE
        WHEN COALESCE(e.ai_emergency_type, e.clasificacion_ia, 'unknown')
          IN ('Grua / remolque', 'GrÃºa / remolque', 'tow_service', 'accident')
          THEN 20
        ELSE 15
      END
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.usuario_id = v_technician.usuario_id
        AND n.tipo = 'nueva_solicitud'
        AND n.referencia_id = e.id
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_pending_on_technician_available()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.estado_verificacion = 'aprobado'
     AND COALESCE(NEW.disponible, false) = true
     AND (
       TG_OP = 'INSERT'
       OR OLD.estado_verificacion IS DISTINCT FROM NEW.estado_verificacion
       OR OLD.disponible IS DISTINCT FROM NEW.disponible
       OR OLD.especialidad IS DISTINCT FROM NEW.especialidad
       OR OLD.ubicacion_lat IS DISTINCT FROM NEW.ubicacion_lat
       OR OLD.ubicacion_lng IS DISTINCT FROM NEW.ubicacion_lng
     ) THEN
    PERFORM public.notify_pending_emergencies_for_technician(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_pending_on_technician_available
  ON public.tecnicos;
CREATE TRIGGER trg_notify_pending_on_technician_available
AFTER INSERT OR UPDATE OF estado_verificacion, disponible, especialidad, ubicacion_lat, ubicacion_lng
ON public.tecnicos
FOR EACH ROW
EXECUTE FUNCTION public.notify_pending_on_technician_available();

DO $$
DECLARE
  technician_row record;
BEGIN
  FOR technician_row IN
    SELECT id
    FROM public.tecnicos
    WHERE estado_verificacion = 'aprobado'
      AND COALESCE(disponible, false) = true
  LOOP
    PERFORM public.notify_pending_emergencies_for_technician(
      technician_row.id
    );
  END LOOP;
END;
$$;
