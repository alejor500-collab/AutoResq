ALTER TABLE public.emergencias
  DROP CONSTRAINT IF EXISTS emergencias_ai_emergency_type_check;

ALTER TABLE public.emergencias
  DROP CONSTRAINT IF EXISTS emergencias_ai_priority_check;

ALTER TABLE public.emergencias
  ALTER COLUMN ai_detected_risks SET DEFAULT ARRAY[]::text[];

UPDATE public.emergencias
SET ai_emergency_type = CASE ai_emergency_type
  WHEN 'minor_mechanic' THEN 'Mecánica rápida'
  WHEN 'engine' THEN 'Mecánica rápida'
  WHEN 'overheating' THEN 'Mecánica rápida'
  WHEN 'brakes' THEN 'Mecánica rápida'
  WHEN 'battery_jumpstart' THEN 'Sistema eléctrico y batería'
  WHEN 'battery' THEN 'Sistema eléctrico y batería'
  WHEN 'electrical' THEN 'Sistema eléctrico y batería'
  WHEN 'tire_change' THEN 'Llantas y vulcanización'
  WHEN 'flat_tire_no_spare' THEN 'Llantas y vulcanización'
  WHEN 'tire' THEN 'Llantas y vulcanización'
  WHEN 'tow_service' THEN 'Grúa / remolque'
  WHEN 'accident' THEN 'Grúa / remolque'
  WHEN 'fuel_delivery' THEN 'Combustible'
  WHEN 'fuel' THEN 'Combustible'
  WHEN 'locksmith_vehicle' THEN 'Cerrajería vehicular'
  WHEN 'lockout' THEN 'Cerrajería vehicular'
  WHEN 'unknown' THEN 'Auxilio general'
  WHEN 'not_emergency' THEN 'Auxilio general'
  ELSE ai_emergency_type
END
WHERE ai_emergency_type IS NOT NULL;

UPDATE public.emergencias
SET ai_priority = CASE ai_priority
  WHEN 'low' THEN 'baja'
  WHEN 'medium' THEN 'media'
  WHEN 'high' THEN 'alta'
  WHEN 'critical' THEN 'alta'
  ELSE ai_priority
END
WHERE ai_priority IS NOT NULL;

ALTER TABLE public.emergencias
  ADD CONSTRAINT emergencias_ai_emergency_type_check
  CHECK (
    ai_emergency_type IS NULL
    OR ai_emergency_type IN (
      'Mecánica rápida',
      'Sistema eléctrico y batería',
      'Llantas y vulcanización',
      'Grúa / remolque',
      'Combustible',
      'Cerrajería vehicular',
      'Auxilio general'
    )
  );

ALTER TABLE public.emergencias
  ADD CONSTRAINT emergencias_ai_priority_check
  CHECK (
    ai_priority IS NULL
    OR ai_priority IN ('baja', 'media', 'alta')
  );
