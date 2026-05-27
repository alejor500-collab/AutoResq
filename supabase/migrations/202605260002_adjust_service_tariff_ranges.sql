UPDATE public.service_tariffs
SET
  pricing_type = 'range',
  base_price = NULL,
  min_price = 1.00,
  max_price = 3.00,
  description = 'Cambio simple de llanta cuando el usuario ya tiene repuesto disponible.',
  includes_text = 'Incluye cambio básico de llanta usando el repuesto del usuario. Esta cuota es solo referencial.',
  excludes_text = 'No incluye compra de llanta, reparación, vulcanización, válvula, aro ni grúa.'
WHERE code = 'tire_change';

UPDATE public.service_tariffs
SET
  pricing_type = 'range',
  base_price = NULL,
  min_price = 3.00,
  max_price = 8.00,
  max_estimated_price = 20.00,
  description = 'Asistencia para rueda pinchada sin repuesto o con posible vulcanización/reparación básica.',
  includes_text = 'Incluye revisión inicial y una cuota referencial si aplica vulcanización o reparación básica.',
  excludes_text = 'No incluye llanta nueva, daños en aro, repuestos mayores ni grúa. Cualquier adicional requiere aprobación.'
WHERE code = 'flat_tire_no_spare';
