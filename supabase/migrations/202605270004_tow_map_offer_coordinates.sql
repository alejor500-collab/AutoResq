-- Include technician coordinates in driver offer queries so pending tow
-- requests can render nearby technicians on the map before the driver chooses.

DROP FUNCTION IF EXISTS public.get_technician_offers_for_driver(uuid);

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
  technician_lat numeric,
  technician_lng numeric,
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
    COALESCE(ut.latitud, t.ubicacion_lat)::numeric AS technician_lat,
    COALESCE(ut.longitud, t.ubicacion_lng)::numeric AS technician_lng,
    o.distancia_km,
    o.eta_minutos,
    o.monto_ofertado,
    o.estado::text,
    o.fecha_oferta
  FROM public.technician_offers o
  JOIN public.tecnicos t ON t.id = o.tecnico_id
  JOIN public.usuarios u ON u.id = t.usuario_id
  JOIN public.emergencias e ON e.id = o.emergencia_id
  LEFT JOIN public.ubicaciones_tecnico ut ON ut.tecnico_id = t.id
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

REVOKE ALL ON FUNCTION public.get_technician_offers_for_driver(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_technician_offers_for_driver(uuid)
  TO authenticated;
