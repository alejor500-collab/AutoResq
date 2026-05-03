-- Las solicitudes tecnicas pendientes/rechazadas no deben bloquear el modo
-- conductor. El rol tecnico se asigna solo cuando el administrador aprueba.
update public.usuarios u
set rol = 'conductor'
from public.tecnicos t
where t.usuario_id = u.id
  and u.rol = 'tecnico'
  and t.estado_verificacion in ('pendiente', 'rechazado');

