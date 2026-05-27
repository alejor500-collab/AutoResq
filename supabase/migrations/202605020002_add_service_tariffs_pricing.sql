-- AutoResQ professional pricing model.
-- IA classifies the emergency; tariffs in Supabase calculate the price.

ALTER TABLE public.emergencias
  DROP CONSTRAINT IF EXISTS emergencias_ai_emergency_type_check;

ALTER TABLE public.emergencias
  ADD CONSTRAINT emergencias_ai_emergency_type_check
  CHECK (
    ai_emergency_type IS NULL
    OR ai_emergency_type IN (
      'tire_change',
      'flat_tire_no_spare',
      'battery_jumpstart',
      'tow_service',
      'minor_mechanic',
      'locksmith_vehicle',
      'fuel_delivery',
      'battery',
      'tire',
      'fuel',
      'engine',
      'overheating',
      'accident',
      'lockout',
      'electrical',
      'brakes',
      'unknown',
      'not_emergency'
    )
  );

CREATE TABLE IF NOT EXISTS public.service_tariffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  pricing_type text NOT NULL
    CHECK (pricing_type IN ('fixed', 'range', 'diagnostic', 'distance_based')),
  base_price numeric(10,2) CHECK (base_price IS NULL OR base_price >= 0),
  min_price numeric(10,2) CHECK (min_price IS NULL OR min_price >= 0),
  max_price numeric(10,2) CHECK (max_price IS NULL OR max_price >= 0),
  minimum_price numeric(10,2) CHECK (minimum_price IS NULL OR minimum_price >= 0),
  max_estimated_price numeric(10,2)
    CHECK (max_estimated_price IS NULL OR max_estimated_price >= 0),
  included_km numeric(10,2) CHECK (included_km IS NULL OR included_km >= 0),
  price_per_km numeric(10,2) CHECK (price_per_km IS NULL OR price_per_km >= 0),
  distance_unit text NOT NULL DEFAULT 'km' CHECK (distance_unit = 'km'),
  rounding_mode text NOT NULL DEFAULT 'exact'
    CHECK (rounding_mode IN ('exact', 'ceil', 'nearest')),
  requires_destination boolean NOT NULL DEFAULT false,
  destination_required_message text,
  includes_text text,
  excludes_text text,
  requires_diagnostic boolean NOT NULL DEFAULT false,
  allows_extra_charges boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT service_tariffs_range_order
    CHECK (min_price IS NULL OR max_price IS NULL OR min_price <= max_price)
);

COMMENT ON TABLE public.service_tariffs IS
  'Tarifario administrado por AutoResQ. La IA no puede definir precios.';

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_service_tariffs_updated ON public.service_tariffs;
CREATE TRIGGER on_service_tariffs_updated
  BEFORE UPDATE ON public.service_tariffs
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_service_tariffs_active_code
  ON public.service_tariffs(code)
  WHERE is_active = true;

INSERT INTO public.service_tariffs (
  code,
  name,
  description,
  pricing_type,
  base_price,
  min_price,
  max_price,
  minimum_price,
  max_estimated_price,
  included_km,
  price_per_km,
  requires_destination,
  destination_required_message,
  includes_text,
  excludes_text,
  requires_diagnostic,
  allows_extra_charges,
  sort_order
) VALUES
  (
    'tire_change',
    'Cambio de llanta',
    'Cambio simple de llanta cuando el usuario ya tiene repuesto disponible.',
    'range',
    NULL,
    1.00,
    3.00,
    NULL,
    NULL,
    NULL,
    NULL,
    false,
    NULL,
    'Incluye cambio básico de llanta usando el repuesto del usuario. Esta cuota es solo referencial.',
    'No incluye compra de llanta, reparacion, vulcanizacion, valvula, aro ni grua.',
    false,
    true,
    10
  ),
  (
    'flat_tire_no_spare',
    'Rueda pinchada sin repuesto',
    'Asistencia para rueda pinchada sin repuesto o con posible vulcanizacion/reparacion basica.',
    'range',
    NULL,
    3.00,
    8.00,
    NULL,
    20.00,
    NULL,
    NULL,
    false,
    NULL,
    'Incluye revision inicial y una cuota referencial si aplica vulcanizacion o reparacion basica.',
    'No incluye llanta nueva, danos en aro, repuestos mayores ni grua. Cualquier adicional requiere aprobacion.',
    false,
    true,
    20
  ),
  (
    'battery_jumpstart',
    'Paso de corriente',
    'Asistencia para bateria descargada.',
    'fixed',
    18.00,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    false,
    NULL,
    'Incluye paso de corriente y verificacion basica de arranque.',
    'No incluye bateria nueva, repuestos ni diagnostico electrico avanzado.',
    false,
    true,
    30
  ),
  (
    'tow_service',
    'Grua / remolque',
    'Traslado del vehiculo desde el punto de emergencia hasta el destino seleccionado.',
    'distance_based',
    35.00,
    NULL,
    NULL,
    35.00,
    150.00,
    5.00,
    1.25,
    true,
    'Por favor, selecciona el destino de traslado para calcular el costo de la grua.',
    'Incluye traslado de hasta 5 km desde el punto de origen.',
    'Peajes, parqueaderos o maniobras especiales de rescate no estan incluidos.',
    false,
    true,
    40
  ),
  (
    'minor_mechanic',
    'Mecanica menor',
    'Revision inicial para problemas mecanicos no claramente identificados.',
    'diagnostic',
    15.00,
    NULL,
    NULL,
    NULL,
    80.00,
    NULL,
    NULL,
    false,
    NULL,
    'Incluye diagnostico inicial y recomendacion tecnica.',
    'Repuestos, reparaciones adicionales o traslado requieren aprobacion.',
    true,
    true,
    50
  ),
  (
    'locksmith_vehicle',
    'Apertura de vehiculo',
    'Servicio para apertura de vehiculo sin dano, segun complejidad.',
    'range',
    NULL,
    20.00,
    45.00,
    NULL,
    NULL,
    NULL,
    NULL,
    false,
    NULL,
    'Incluye intento de apertura sin dano usando herramientas apropiadas.',
    'No incluye duplicado de llave, reparacion de cerradura ni modulos electronicos.',
    false,
    true,
    60
  ),
  (
    'fuel_delivery',
    'Entrega de combustible',
    'Asistencia por falta de combustible.',
    'range',
    NULL,
    12.00,
    25.00,
    NULL,
    NULL,
    NULL,
    NULL,
    false,
    NULL,
    'Incluye traslado del tecnico para entrega inicial de combustible.',
    'El combustible se cobra aparte contra factura o evidencia de compra.',
    false,
    true,
    70
  )
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  pricing_type = EXCLUDED.pricing_type,
  base_price = EXCLUDED.base_price,
  min_price = EXCLUDED.min_price,
  max_price = EXCLUDED.max_price,
  minimum_price = EXCLUDED.minimum_price,
  max_estimated_price = EXCLUDED.max_estimated_price,
  included_km = EXCLUDED.included_km,
  price_per_km = EXCLUDED.price_per_km,
  requires_destination = EXCLUDED.requires_destination,
  destination_required_message = EXCLUDED.destination_required_message,
  includes_text = EXCLUDED.includes_text,
  excludes_text = EXCLUDED.excludes_text,
  requires_diagnostic = EXCLUDED.requires_diagnostic,
  allows_extra_charges = EXCLUDED.allows_extra_charges,
  sort_order = EXCLUDED.sort_order,
  is_active = true,
  version = public.service_tariffs.version + 1,
  updated_at = now();

CREATE TABLE IF NOT EXISTS public.emergency_price_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emergency_id uuid NOT NULL UNIQUE REFERENCES public.emergencias(id) ON DELETE CASCADE,
  tariff_id uuid REFERENCES public.service_tariffs(id),
  snapshot jsonb NOT NULL,
  pricing_type text NOT NULL
    CHECK (pricing_type IN ('fixed', 'range', 'diagnostic', 'distance_based')),
  pricing_status text NOT NULL
    CHECK (pricing_status IN (
      'estimated',
      'protected',
      'pending_destination',
      'pending_manual_review',
      'final'
    )),
  service_code text NOT NULL,
  currency text NOT NULL DEFAULT 'USD',
  estimated_total numeric(10,2) CHECK (estimated_total IS NULL OR estimated_total >= 0),
  protected_total numeric(10,2) CHECK (protected_total IS NULL OR protected_total >= 0),
  final_total numeric(10,2) CHECK (final_total IS NULL OR final_total >= 0),
  requires_manual_review boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.emergency_price_snapshots IS
  'Snapshot inmutable del precio usado al crear una emergencia.';

CREATE INDEX IF NOT EXISTS idx_emergency_price_snapshots_emergency
  ON public.emergency_price_snapshots(emergency_id);

CREATE TABLE IF NOT EXISTS public.emergency_extra_charges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emergency_id uuid NOT NULL REFERENCES public.emergencias(id) ON DELETE CASCADE,
  technician_id uuid REFERENCES public.usuarios(id),
  amount numeric(10,2) NOT NULL CHECK (amount > 0),
  category text NOT NULL
    CHECK (category IN (
      'toll',
      'parking',
      'special_maneuver',
      'rescue',
      'waiting_time',
      'spare_part',
      'material',
      'route_change',
      'other'
    )),
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  evidence_photo_url text,
  invoice_url text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz
);

COMMENT ON TABLE public.emergency_extra_charges IS
  'Cargos adicionales solicitados por el tecnico y aprobados/rechazados por el usuario.';

CREATE INDEX IF NOT EXISTS idx_emergency_extra_charges_emergency
  ON public.emergency_extra_charges(emergency_id);

CREATE INDEX IF NOT EXISTS idx_emergency_extra_charges_pending
  ON public.emergency_extra_charges(emergency_id, status)
  WHERE status = 'pending';

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

CREATE OR REPLACE FUNCTION public.has_pending_service_rating(
  p_user_id uuid,
  p_role text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.emergencias e
    LEFT JOIN public.calificaciones c
      ON c.emergencia_id = e.id
     AND c.calificador_id = p_user_id
     AND c.rater_role = p_role
    WHERE e.estado = 'finalizada'
      AND c.id IS NULL
      AND (
        (p_role = 'driver' AND e.usuario_id = p_user_id)
        OR (
          p_role = 'technician'
          AND EXISTS (
            SELECT 1
            FROM public.asignaciones a
            LEFT JOIN public.tecnicos t ON t.id = a.tecnico_id
            WHERE a.emergencia_id = e.id
              AND (
                t.usuario_id = p_user_id
                OR a.tecnico_id = p_user_id
              )
          )
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.get_pending_service_rating(
  p_user_id uuid,
  p_role text
)
RETURNS TABLE (
  emergency_id uuid,
  rated_user_id uuid,
  rated_user_name text,
  rater_role text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    e.id AS emergency_id,
    CASE
      WHEN p_role = 'driver' THEN COALESCE(t.usuario_id, a.tecnico_id)
      ELSE e.usuario_id
    END AS rated_user_id,
    CASE
      WHEN p_role = 'driver' THEN COALESCE(ut.nombre, 'Tecnico')
      ELSE COALESCE(ud.nombre, 'Conductor')
    END AS rated_user_name,
    p_role AS rater_role
  FROM public.emergencias e
  LEFT JOIN public.asignaciones a ON a.emergencia_id = e.id
  LEFT JOIN public.tecnicos t ON t.id = a.tecnico_id OR t.usuario_id = a.tecnico_id
  LEFT JOIN public.usuarios ut ON ut.id = COALESCE(t.usuario_id, a.tecnico_id)
  LEFT JOIN public.usuarios ud ON ud.id = e.usuario_id
  LEFT JOIN public.calificaciones c
    ON c.emergencia_id = e.id
   AND c.calificador_id = p_user_id
   AND c.rater_role = p_role
  WHERE e.estado = 'finalizada'
    AND c.id IS NULL
    AND (
      (p_role = 'driver' AND e.usuario_id = p_user_id)
      OR (
        p_role = 'technician'
        AND (
          t.usuario_id = p_user_id
          OR a.tecnico_id = p_user_id
        )
      )
    )
  ORDER BY e.fecha ASC
  LIMIT 1;
$$;

ALTER TABLE public.service_tariffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_price_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_extra_charges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_tariffs_select_authenticated" ON public.service_tariffs;
CREATE POLICY "service_tariffs_select_authenticated" ON public.service_tariffs
  FOR SELECT TO authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS "service_tariffs_admin_all" ON public.service_tariffs;
CREATE POLICY "service_tariffs_admin_all" ON public.service_tariffs
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios u
      WHERE u.id = auth.uid() AND u.rol = 'administrador'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.usuarios u
      WHERE u.id = auth.uid() AND u.rol = 'administrador'
    )
  );

DROP POLICY IF EXISTS "price_snapshots_select_participants" ON public.emergency_price_snapshots;
CREATE POLICY "price_snapshots_select_participants" ON public.emergency_price_snapshots
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.id = emergency_id
        AND (
          e.usuario_id = auth.uid()
          OR EXISTS (
            SELECT 1
            FROM public.asignaciones a
            LEFT JOIN public.tecnicos t ON t.id = a.tecnico_id
            WHERE a.emergencia_id = e.id
              AND (
                t.usuario_id = auth.uid()
                OR a.tecnico_id = auth.uid()
              )
          )
          OR EXISTS (
            SELECT 1 FROM public.usuarios u
            WHERE u.id = auth.uid() AND u.rol = 'administrador'
          )
        )
    )
  );

DROP POLICY IF EXISTS "price_snapshots_insert_driver" ON public.emergency_price_snapshots;
CREATE POLICY "price_snapshots_insert_driver" ON public.emergency_price_snapshots
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.id = emergency_id
        AND e.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "extra_charges_select_participants" ON public.emergency_extra_charges;
CREATE POLICY "extra_charges_select_participants" ON public.emergency_extra_charges
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.id = emergency_id
        AND (
          e.usuario_id = auth.uid()
          OR technician_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.usuarios u
            WHERE u.id = auth.uid() AND u.rol = 'administrador'
          )
        )
    )
  );

DROP POLICY IF EXISTS "extra_charges_insert_assigned_technician" ON public.emergency_extra_charges;
CREATE POLICY "extra_charges_insert_assigned_technician" ON public.emergency_extra_charges
  FOR INSERT TO authenticated
  WITH CHECK (
    technician_id = auth.uid()
    AND status = 'pending'
    AND EXISTS (
      SELECT 1
      FROM public.asignaciones a
      LEFT JOIN public.tecnicos t ON t.id = a.tecnico_id
      WHERE a.emergencia_id = emergency_id
        AND (
          t.usuario_id = auth.uid()
          OR a.tecnico_id = auth.uid()
        )
    )
  );

DROP POLICY IF EXISTS "extra_charges_update_driver_or_technician_cancel" ON public.emergency_extra_charges;
CREATE POLICY "extra_charges_update_driver_or_technician_cancel" ON public.emergency_extra_charges
  FOR UPDATE TO authenticated
  USING (
    (
      status = 'pending'
      AND EXISTS (
        SELECT 1
        FROM public.emergencias e
        WHERE e.id = emergency_id
          AND e.usuario_id = auth.uid()
      )
    )
    OR (
      status = 'pending'
      AND technician_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.usuarios u
      WHERE u.id = auth.uid() AND u.rol = 'administrador'
    )
  )
  WITH CHECK (
    (
      EXISTS (
        SELECT 1
        FROM public.emergencias e
        WHERE e.id = emergency_id
          AND e.usuario_id = auth.uid()
      )
      AND status IN ('accepted', 'rejected')
      AND responded_at IS NOT NULL
    )
    OR (
      technician_id = auth.uid()
      AND status = 'cancelled'
    )
    OR EXISTS (
      SELECT 1 FROM public.usuarios u
      WHERE u.id = auth.uid() AND u.rol = 'administrador'
    )
  );

DROP POLICY IF EXISTS "calificaciones_insert_participante" ON public.calificaciones;
CREATE POLICY "calificaciones_insert_participante" ON public.calificaciones
  FOR INSERT TO authenticated
  WITH CHECK (
    calificador_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.emergencias e
      WHERE e.id = emergencia_id
        AND e.estado = 'finalizada'
        AND (
          (
            rater_role = 'driver'
            AND e.usuario_id = auth.uid()
          )
          OR (
            rater_role = 'technician'
            AND EXISTS (
              SELECT 1
              FROM public.asignaciones a
              LEFT JOIN public.tecnicos t ON t.id = a.tecnico_id
              WHERE a.emergencia_id = e.id
                AND (
                  t.usuario_id = auth.uid()
                  OR a.tecnico_id = auth.uid()
                )
            )
          )
        )
    )
  );
