-- Break the usuarios <-> tecnicos RLS cycle.
-- A usuarios policy queried tecnicos, while tecnicos policies queried usuarios
-- for admin checks. SECURITY DEFINER helpers read with RLS disabled.

CREATE OR REPLACE FUNCTION public.es_tecnico_aprobado(user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.tecnicos
    WHERE usuario_id = user_id
      AND estado_verificacion = 'aprobado'
  );
$$;

REVOKE ALL ON FUNCTION public.es_tecnico_aprobado(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.es_tecnico_aprobado(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.es_tecnico_aprobado(uuid) TO service_role;

DROP POLICY IF EXISTS "usuarios_select_pending_emergency_driver_for_technicians"
  ON public.usuarios;
CREATE POLICY "usuarios_select_pending_emergency_driver_for_technicians"
  ON public.usuarios
  FOR SELECT TO authenticated
  USING (
    public.es_tecnico_aprobado(auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.usuario_id = usuarios.id
        AND e.estado = 'pendiente'
    )
  );

DROP POLICY IF EXISTS "tecnicos_admin_all" ON public.tecnicos;
CREATE POLICY "tecnicos_admin_all" ON public.tecnicos
  FOR ALL TO authenticated
  USING (public.get_rol_usuario(auth.uid()) = 'administrador')
  WITH CHECK (public.get_rol_usuario(auth.uid()) = 'administrador');

DROP POLICY IF EXISTS "tecnicos_select_aprobados" ON public.tecnicos;
CREATE POLICY "tecnicos_select_aprobados" ON public.tecnicos
  FOR SELECT TO authenticated
  USING (
    (estado_verificacion = 'aprobado' AND disponible = true)
    OR usuario_id = auth.uid()
    OR public.get_rol_usuario(auth.uid()) = 'administrador'
  );
