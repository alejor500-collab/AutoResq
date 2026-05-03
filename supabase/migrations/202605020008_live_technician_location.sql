-- Keep one live location row per technician for driver-side tracking.

DELETE FROM public.ubicaciones_tecnico a
USING public.ubicaciones_tecnico b
WHERE a.tecnico_id = b.tecnico_id
  AND a.actualizado_en < b.actualizado_en;

CREATE UNIQUE INDEX IF NOT EXISTS ubicaciones_tecnico_tecnico_id_key
  ON public.ubicaciones_tecnico(tecnico_id);

DROP POLICY IF EXISTS "ubicaciones_tecnico_select" ON public.ubicaciones_tecnico;
CREATE POLICY "ubicaciones_tecnico_select" ON public.ubicaciones_tecnico
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.tecnicos t
      WHERE t.id = ubicaciones_tecnico.tecnico_id
        AND t.usuario_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM public.asignaciones a
      JOIN public.emergencias e ON e.id = a.emergencia_id
      WHERE a.tecnico_id = ubicaciones_tecnico.tecnico_id
        AND e.usuario_id = auth.uid()
        AND a.estado IN ('aceptada', 'en_ruta', 'atendiendo')
    )
    OR public.get_rol_usuario(auth.uid()) = 'administrador'
  );

DROP POLICY IF EXISTS "ubicaciones_tecnico_update_own" ON public.ubicaciones_tecnico;
CREATE POLICY "ubicaciones_tecnico_update_own" ON public.ubicaciones_tecnico
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.tecnicos t
      WHERE t.id = ubicaciones_tecnico.tecnico_id
        AND t.usuario_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.tecnicos t
      WHERE t.id = ubicaciones_tecnico.tecnico_id
        AND t.usuario_id = auth.uid()
    )
  );
