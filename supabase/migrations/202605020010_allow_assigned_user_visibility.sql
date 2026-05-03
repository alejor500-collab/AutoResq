-- Allow assigned driver/technician pairs to see each other's public profile
-- data during an active service without opening the whole usuarios table.

CREATE OR REPLACE FUNCTION public.puede_ver_usuario_por_asignacion(
  target_user_id uuid,
  viewer_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $$
  SELECT target_user_id = viewer_user_id
    OR public.get_rol_usuario(viewer_user_id) = 'administrador'
    OR EXISTS (
      SELECT 1
      FROM public.emergencias e
      JOIN public.asignaciones a ON a.emergencia_id = e.id
      JOIN public.tecnicos t ON t.id = a.tecnico_id
      WHERE a.estado IN ('aceptada', 'en_ruta', 'atendiendo', 'finalizada')
        AND (
          (e.usuario_id = viewer_user_id AND t.usuario_id = target_user_id)
          OR (t.usuario_id = viewer_user_id AND e.usuario_id = target_user_id)
        )
    );
$$;

REVOKE ALL ON FUNCTION public.puede_ver_usuario_por_asignacion(uuid, uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.puede_ver_usuario_por_asignacion(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.puede_ver_usuario_por_asignacion(uuid, uuid)
  TO service_role;

DROP POLICY IF EXISTS "usuarios_select_assigned_participants"
  ON public.usuarios;
CREATE POLICY "usuarios_select_assigned_participants"
  ON public.usuarios
  FOR SELECT TO authenticated
  USING (public.puede_ver_usuario_por_asignacion(id, auth.uid()));

CREATE OR REPLACE FUNCTION public.puede_ver_tecnico_por_asignacion(
  target_tecnico_id uuid,
  viewer_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $$
  SELECT public.get_rol_usuario(viewer_user_id) = 'administrador'
    OR EXISTS (
      SELECT 1
      FROM public.tecnicos t
      WHERE t.id = target_tecnico_id
        AND t.usuario_id = viewer_user_id
    )
    OR EXISTS (
      SELECT 1
      FROM public.emergencias e
      JOIN public.asignaciones a ON a.emergencia_id = e.id
      WHERE a.tecnico_id = target_tecnico_id
        AND a.estado IN ('aceptada', 'en_ruta', 'atendiendo', 'finalizada')
        AND e.usuario_id = viewer_user_id
    );
$$;

REVOKE ALL ON FUNCTION public.puede_ver_tecnico_por_asignacion(uuid, uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.puede_ver_tecnico_por_asignacion(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.puede_ver_tecnico_por_asignacion(uuid, uuid)
  TO service_role;

DROP POLICY IF EXISTS "tecnicos_select_assigned_participants"
  ON public.tecnicos;
CREATE POLICY "tecnicos_select_assigned_participants"
  ON public.tecnicos
  FOR SELECT TO authenticated
  USING (public.puede_ver_tecnico_por_asignacion(id, auth.uid()));
