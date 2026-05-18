ALTER TABLE public.notificaciones
  DROP CONSTRAINT IF EXISTS notificaciones_tipo_check;

ALTER TABLE public.notificaciones
  ADD CONSTRAINT notificaciones_tipo_check
  CHECK (tipo IN (
    'nueva_solicitud',
    'solicitud_aceptada',
    'tecnico_en_ruta',
    'servicio_finalizado',
    'nueva_calificacion',
    'verificacion_aprobada',
    'verificacion_rechazada',
    'nuevo_mensaje',
    'solicitud_cancelada',
    'tecnico_cancelo'
  ));

CREATE OR REPLACE FUNCTION public.notify_new_emergency_in_app()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notificaciones (usuario_id, tipo, mensaje, referencia_id)
  SELECT
    t.usuario_id,
    'nueva_solicitud',
    'Nueva solicitud disponible cerca de tu zona. Revisa los detalles y envia tu oferta si puedes atenderla.',
    NEW.id
  FROM public.tecnicos t
  WHERE t.estado_verificacion = 'aprobado'
    AND COALESCE(t.disponible, false) = true;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_emergency_in_app ON public.emergencias;
CREATE TRIGGER trg_notify_new_emergency_in_app
AFTER INSERT ON public.emergencias
FOR EACH ROW
WHEN (NEW.estado = 'pendiente')
EXECUTE FUNCTION public.notify_new_emergency_in_app();

CREATE OR REPLACE FUNCTION public.notify_message_in_app()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emergency public.emergencias%ROWTYPE;
  v_technician_user_id uuid;
  v_receiver_id uuid;
BEGIN
  SELECT * INTO v_emergency
  FROM public.emergencias
  WHERE id = (
    SELECT emergencia_id
    FROM public.asignaciones
    WHERE id = NEW.asignacion_id
  );

  SELECT t.usuario_id INTO v_technician_user_id
  FROM public.asignaciones a
  JOIN public.tecnicos t ON t.id = a.tecnico_id
  WHERE a.id = NEW.asignacion_id;

  IF NEW.remitente_id = v_emergency.usuario_id THEN
    v_receiver_id := v_technician_user_id;
  ELSE
    v_receiver_id := v_emergency.usuario_id;
  END IF;

  IF v_receiver_id IS NOT NULL THEN
    INSERT INTO public.notificaciones (usuario_id, tipo, mensaje, referencia_id)
    VALUES (
      v_receiver_id,
      'nuevo_mensaje',
      'Tienes un nuevo mensaje en el chat del servicio.',
      v_emergency.id
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_message_in_app ON public.mensajes;
CREATE TRIGGER trg_notify_message_in_app
AFTER INSERT ON public.mensajes
FOR EACH ROW
EXECUTE FUNCTION public.notify_message_in_app();

CREATE OR REPLACE FUNCTION public.notify_emergency_cancelled_in_app()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado AND NEW.estado = 'cancelada' THEN
    INSERT INTO public.notificaciones (usuario_id, tipo, mensaje, referencia_id)
    SELECT
      t.usuario_id,
      'solicitud_cancelada',
      'El conductor cancelo la solicitud. Ya no es necesario atender este servicio.',
      NEW.id
    FROM public.asignaciones a
    JOIN public.tecnicos t ON t.id = a.tecnico_id
    WHERE a.emergencia_id = NEW.id
      AND a.estado IN ('aceptada', 'en_ruta', 'atendiendo');

    INSERT INTO public.historial (emergencia_id, actor_id, tipo_evento, descripcion)
    VALUES (NEW.id, NEW.usuario_id, 'cancelacion', 'Solicitud cancelada por el conductor');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_emergency_cancelled_in_app ON public.emergencias;
CREATE TRIGGER trg_notify_emergency_cancelled_in_app
AFTER UPDATE OF estado ON public.emergencias
FOR EACH ROW
EXECUTE FUNCTION public.notify_emergency_cancelled_in_app();

CREATE OR REPLACE FUNCTION public.technician_cancel_service(p_emergency_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_assignment public.asignaciones%ROWTYPE;
  v_technician_id uuid;
  v_driver_id uuid;
BEGIN
  SELECT t.id INTO v_technician_id
  FROM public.tecnicos t
  WHERE t.usuario_id = auth.uid();

  IF v_technician_id IS NULL THEN
    RAISE EXCEPTION 'No se encontro el perfil tecnico.';
  END IF;

  SELECT * INTO v_assignment
  FROM public.asignaciones
  WHERE emergencia_id = p_emergency_id
    AND tecnico_id = v_technician_id
    AND estado IN ('aceptada', 'en_ruta', 'atendiendo')
  ORDER BY fecha_asignacion DESC
  LIMIT 1;

  IF v_assignment.id IS NULL THEN
    RAISE EXCEPTION 'No tienes una asignacion activa para esta solicitud.';
  END IF;

  SELECT usuario_id INTO v_driver_id
  FROM public.emergencias
  WHERE id = p_emergency_id;

  UPDATE public.asignaciones
  SET estado = 'rechazada'
  WHERE id = v_assignment.id;

  UPDATE public.emergencias
  SET estado = 'pendiente'
  WHERE id = p_emergency_id;

  UPDATE public.technician_offers
  SET estado = 'cancelada',
      fecha_respuesta = now()
  WHERE emergencia_id = p_emergency_id
    AND tecnico_id = v_technician_id;

  UPDATE public.tecnicos
  SET disponible = false
  WHERE id = v_technician_id;

  INSERT INTO public.notificaciones (usuario_id, tipo, mensaje, referencia_id)
  VALUES (
    v_driver_id,
    'tecnico_cancelo',
    'El tecnico tuvo que cancelar la atencion. Tu solicitud vuelve a estar disponible para que otro tecnico pueda ayudarte.',
    p_emergency_id
  );

  INSERT INTO public.historial (emergencia_id, actor_id, tipo_evento, descripcion)
  VALUES (
    p_emergency_id,
    auth.uid(),
    'cancelacion',
    'El tecnico cancelo la atencion. La solicitud vuelve a pendiente.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.technician_cancel_service(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.technician_cancel_service(uuid) TO authenticated;
