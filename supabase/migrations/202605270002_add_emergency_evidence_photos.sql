alter table public.emergencias
  add column if not exists evidence_photo_urls text[] not null default array[]::text[];

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'emergency-photos',
  'emergency-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "emergency_photos_select_public" on storage.objects;
create policy "emergency_photos_select_public"
  on storage.objects
  for select
  using (bucket_id = 'emergency-photos');

drop policy if exists "emergency_photos_insert_authenticated" on storage.objects;
create policy "emergency_photos_insert_authenticated"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'emergency-photos');

drop policy if exists "emergency_photos_update_owner" on storage.objects;
create policy "emergency_photos_update_owner"
  on storage.objects
  for update
  to authenticated
  using (bucket_id = 'emergency-photos' and owner = auth.uid())
  with check (bucket_id = 'emergency-photos' and owner = auth.uid());
