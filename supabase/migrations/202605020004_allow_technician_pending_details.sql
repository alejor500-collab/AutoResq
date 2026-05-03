-- Allow approved technicians to see the information needed to decide whether
-- they can accept a pending emergency. The base price remains immutable.

DROP POLICY IF EXISTS "usuarios_select_pending_emergency_driver_for_technicians"
  ON public.usuarios;
CREATE POLICY "usuarios_select_pending_emergency_driver_for_technicians"
  ON public.usuarios
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.tecnicos t
      WHERE t.usuario_id = auth.uid()
        AND t.estado_verificacion = 'aprobado'
    )
    AND EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.usuario_id = usuarios.id
        AND e.estado = 'pendiente'
    )
  );

DROP POLICY IF EXISTS "ubicaciones_select_pending_approved_technicians"
  ON public.ubicaciones;
CREATE POLICY "ubicaciones_select_pending_approved_technicians"
  ON public.ubicaciones
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.tecnicos t
      WHERE t.usuario_id = auth.uid()
        AND t.estado_verificacion = 'aprobado'
    )
    AND EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.id = ubicaciones.emergencia_id
        AND e.estado = 'pendiente'
    )
  );

DROP POLICY IF EXISTS "price_snapshots_select_pending_approved_technicians"
  ON public.emergency_price_snapshots;
CREATE POLICY "price_snapshots_select_pending_approved_technicians"
  ON public.emergency_price_snapshots
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.tecnicos t
      WHERE t.usuario_id = auth.uid()
        AND t.estado_verificacion = 'aprobado'
    )
    AND EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.id = emergency_price_snapshots.emergency_id
        AND e.estado = 'pendiente'
    )
  );
