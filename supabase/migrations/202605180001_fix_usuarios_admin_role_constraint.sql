-- Normaliza el rol de administrador para que coincida con la app
-- y corrige bases remotas que aun conservan un CHECK antiguo.

update public.usuarios
set rol = 'administrador'
where rol = 'admin';

alter table public.usuarios
drop constraint if exists usuarios_rol_check;

alter table public.usuarios
add constraint usuarios_rol_check
check (rol in ('conductor', 'tecnico', 'administrador'));
