-- Let an approved assigned technician advance the emergency row after
-- accepting. The protected price snapshot remains untouched.

DROP POLICY IF EXISTS "emergencias_update_assigned_technician"
  ON public.emergencias;
CREATE POLICY "emergencias_update_assigned_technician"
  ON public.emergencias
  FOR UPDATE TO authenticated
  USING (public.es_tecnico_asignado(id, auth.uid()))
  WITH CHECK (public.es_tecnico_asignado(id, auth.uid()));

-- Backfill emergencies that were accepted while the UPDATE policy was missing.
UPDATE public.emergencias e
SET estado = 'en_proceso'
WHERE e.estado = 'pendiente'
  AND EXISTS (
    SELECT 1
    FROM public.asignaciones a
    WHERE a.emergencia_id = e.id
      AND a.estado IN ('aceptada', 'en_ruta', 'atendiendo')
  );
