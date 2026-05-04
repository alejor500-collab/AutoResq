ALTER TABLE public.asignaciones
  ADD COLUMN IF NOT EXISTS fecha_llegada timestamptz;

COMMENT ON COLUMN public.asignaciones.fecha_llegada IS
  'Momento en que el tecnico confirma "He llegado"; se usa para contar la duracion real de atencion.';
