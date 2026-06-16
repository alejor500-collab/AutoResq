alter table public.usuarios
  add column if not exists ultimo_acceso timestamptz;

update public.usuarios as profile
set ultimo_acceso = auth_user.last_sign_in_at
from auth.users as auth_user
where auth_user.id = profile.id
  and auth_user.last_sign_in_at is not null
  and profile.ultimo_acceso is distinct from auth_user.last_sign_in_at;

create or replace function public.sync_usuario_ultimo_acceso()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.last_sign_in_at is distinct from old.last_sign_in_at then
    update public.usuarios
    set ultimo_acceso = new.last_sign_in_at
    where id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_usuario_ultimo_acceso
  on auth.users;
create trigger sync_usuario_ultimo_acceso
  after update of last_sign_in_at on auth.users
  for each row
  execute function public.sync_usuario_ultimo_acceso();
