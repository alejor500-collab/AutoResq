-- Add explicit chat delivery/read timestamps so the UI can distinguish:
-- sent (one check), delivered (two checks), and read (two blue checks).

ALTER TABLE public.mensajes
  ADD COLUMN IF NOT EXISTS entregado_at timestamptz,
  ADD COLUMN IF NOT EXISTS leido_at timestamptz;

UPDATE public.mensajes
SET leido_at = COALESCE(leido_at, fecha_envio),
    entregado_at = COALESCE(entregado_at, fecha_envio)
WHERE leido = true;

DROP POLICY IF EXISTS "mensajes_participantes" ON public.mensajes;
DROP POLICY IF EXISTS "mensajes_select_participantes" ON public.mensajes;
DROP POLICY IF EXISTS "mensajes_insert_participantes" ON public.mensajes;
DROP POLICY IF EXISTS "mensajes_update_receptor" ON public.mensajes;

CREATE POLICY "mensajes_select_participantes" ON public.mensajes
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.asignaciones a
      JOIN public.emergencias e ON e.id = a.emergencia_id
      JOIN public.tecnicos t ON t.id = a.tecnico_id
      WHERE a.id = asignacion_id
        AND (e.usuario_id = auth.uid() OR t.usuario_id = auth.uid())
    )
  );

CREATE POLICY "mensajes_insert_participantes" ON public.mensajes
  FOR INSERT TO authenticated
  WITH CHECK (
    remitente_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.asignaciones a
      JOIN public.emergencias e ON e.id = a.emergencia_id
      JOIN public.tecnicos t ON t.id = a.tecnico_id
      WHERE a.id = asignacion_id
        AND (e.usuario_id = auth.uid() OR t.usuario_id = auth.uid())
    )
  );

CREATE POLICY "mensajes_update_receptor" ON public.mensajes
  FOR UPDATE TO authenticated
  USING (
    remitente_id <> auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.asignaciones a
      JOIN public.emergencias e ON e.id = a.emergencia_id
      JOIN public.tecnicos t ON t.id = a.tecnico_id
      WHERE a.id = asignacion_id
        AND (e.usuario_id = auth.uid() OR t.usuario_id = auth.uid())
    )
  )
  WITH CHECK (
    remitente_id <> auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.asignaciones a
      JOIN public.emergencias e ON e.id = a.emergencia_id
      JOIN public.tecnicos t ON t.id = a.tecnico_id
      WHERE a.id = asignacion_id
        AND (e.usuario_id = auth.uid() OR t.usuario_id = auth.uid())
    )
  );
