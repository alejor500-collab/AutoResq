-- Keep user and technician rating stats consistent after every rating/service
-- change. This repairs older databases where the trigger only existed in
-- schema.sql or only updated the technician average once.

ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS calificacion_promedio numeric(3,2) NOT NULL DEFAULT 0.00;

ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS total_servicios integer NOT NULL DEFAULT 0;

ALTER TABLE public.tecnicos
  ADD COLUMN IF NOT EXISTS total_servicios integer NOT NULL DEFAULT 0;

ALTER TABLE public.calificaciones
  ADD COLUMN IF NOT EXISTS rater_role text;

UPDATE public.calificaciones c
SET rater_role = CASE
  WHEN e.usuario_id = c.calificador_id THEN 'driver'
  ELSE 'technician'
END
FROM public.emergencias e
WHERE e.id = c.emergencia_id
  AND c.rater_role IS NULL;

ALTER TABLE public.calificaciones
  ALTER COLUMN rater_role SET DEFAULT 'driver';

ALTER TABLE public.calificaciones
  DROP CONSTRAINT IF EXISTS calificaciones_rater_role_check;

ALTER TABLE public.calificaciones
  ADD CONSTRAINT calificaciones_rater_role_check
  CHECK (rater_role IN ('driver', 'technician'));

CREATE UNIQUE INDEX IF NOT EXISTS calificaciones_one_per_role_per_emergency
  ON public.calificaciones(emergencia_id, rater_role);

CREATE OR REPLACE FUNCTION public.recalculate_user_rating_stats(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_average numeric(3,2);
  v_total_services integer;
BEGIN
  SELECT ROUND(AVG(c.puntuacion)::numeric, 2)
  INTO v_average
  FROM public.calificaciones c
  WHERE c.calificado_id = p_user_id;

  SELECT COUNT(DISTINCT e.id)
  INTO v_total_services
  FROM public.emergencias e
  LEFT JOIN public.asignaciones a ON a.emergencia_id = e.id
  LEFT JOIN public.tecnicos t ON t.id = a.tecnico_id OR t.usuario_id = a.tecnico_id
  WHERE e.estado = 'finalizada'
    AND (
      e.usuario_id = p_user_id
      OR t.usuario_id = p_user_id
      OR a.tecnico_id = p_user_id
    );

  UPDATE public.usuarios
  SET
    calificacion_promedio = COALESCE(v_average, 0.00),
    total_servicios = COALESCE(v_total_services, 0),
    actualizado_en = now()
  WHERE id = p_user_id;

  UPDATE public.tecnicos
  SET
    calificacion_promedio = COALESCE(v_average, 0.00),
    total_servicios = COALESCE(v_total_services, 0)
  WHERE usuario_id = p_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.recalculate_emergency_participant_rating_stats(
  p_emergency_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  FOR v_user_id IN
    SELECT e.usuario_id
    FROM public.emergencias e
    WHERE e.id = p_emergency_id
    UNION
    SELECT COALESCE(
      t.usuario_id,
      CASE
        WHEN EXISTS (
          SELECT 1 FROM public.usuarios u WHERE u.id = a.tecnico_id
        ) THEN a.tecnico_id
      END
    )
    FROM public.asignaciones a
    LEFT JOIN public.tecnicos t ON t.id = a.tecnico_id OR t.usuario_id = a.tecnico_id
    WHERE a.emergencia_id = p_emergency_id
  LOOP
    IF v_user_id IS NOT NULL THEN
      PERFORM public.recalculate_user_rating_stats(v_user_id);
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_rating_stats_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recalculate_user_rating_stats(OLD.calificado_id);
    PERFORM public.recalculate_user_rating_stats(OLD.calificador_id);
    RETURN OLD;
  END IF;

  PERFORM public.recalculate_user_rating_stats(NEW.calificado_id);
  PERFORM public.recalculate_user_rating_stats(NEW.calificador_id);

  IF TG_OP = 'UPDATE' AND OLD.calificado_id IS DISTINCT FROM NEW.calificado_id THEN
    PERFORM public.recalculate_user_rating_stats(OLD.calificado_id);
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_emergency_rating_stats_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recalculate_emergency_participant_rating_stats(OLD.id);
    RETURN OLD;
  END IF;

  PERFORM public.recalculate_emergency_participant_rating_stats(NEW.id);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_assignment_rating_stats_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recalculate_emergency_participant_rating_stats(OLD.emergencia_id);
    RETURN OLD;
  END IF;

  PERFORM public.recalculate_emergency_participant_rating_stats(NEW.emergencia_id);

  IF TG_OP = 'UPDATE' AND OLD.emergencia_id IS DISTINCT FROM NEW.emergencia_id THEN
    PERFORM public.recalculate_emergency_participant_rating_stats(OLD.emergencia_id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_calificacion_inserted ON public.calificaciones;
DROP TRIGGER IF EXISTS on_rating_stats_changed ON public.calificaciones;
CREATE TRIGGER on_rating_stats_changed
  AFTER INSERT OR UPDATE OR DELETE ON public.calificaciones
  FOR EACH ROW
  EXECUTE FUNCTION public.on_rating_stats_changed();

DROP TRIGGER IF EXISTS on_emergency_rating_stats_changed ON public.emergencias;
CREATE TRIGGER on_emergency_rating_stats_changed
  AFTER INSERT OR UPDATE OF estado OR DELETE ON public.emergencias
  FOR EACH ROW
  EXECUTE FUNCTION public.on_emergency_rating_stats_changed();

DROP TRIGGER IF EXISTS on_assignment_rating_stats_changed ON public.asignaciones;
CREATE TRIGGER on_assignment_rating_stats_changed
  AFTER INSERT OR UPDATE OF estado, tecnico_id, emergencia_id OR DELETE ON public.asignaciones
  FOR EACH ROW
  EXECUTE FUNCTION public.on_assignment_rating_stats_changed();

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT id FROM public.usuarios LOOP
    PERFORM public.recalculate_user_rating_stats(r.id);
  END LOOP;
END;
$$;
