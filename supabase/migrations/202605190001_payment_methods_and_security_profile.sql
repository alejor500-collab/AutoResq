alter table public.usuarios
  add column if not exists preferred_payment_method text not null default 'cash';

alter table public.usuarios
  drop constraint if exists usuarios_preferred_payment_method_check;

alter table public.usuarios
  add constraint usuarios_preferred_payment_method_check
  check (preferred_payment_method in ('cash', 'transfer'));

alter table public.emergencias
  add column if not exists payment_method text not null default 'cash';

alter table public.emergencias
  drop constraint if exists emergencias_payment_method_check;

alter table public.emergencias
  add constraint emergencias_payment_method_check
  check (payment_method in ('cash', 'transfer'));
