DROP POLICY IF EXISTS "historial_insert_participants" ON public.historial;

CREATE POLICY "historial_insert_participants" ON public.historial
  FOR INSERT TO authenticated
  WITH CHECK (
    actor_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.id = emergencia_id
        AND (
          e.usuario_id = auth.uid()
          OR EXISTS (
            SELECT 1
            FROM public.asignaciones a
            LEFT JOIN public.tecnicos t ON t.id = a.tecnico_id
            WHERE a.emergencia_id = e.id
              AND (
                a.tecnico_id = auth.uid()
                OR t.usuario_id = auth.uid()
              )
          )
        )
    )
  );
