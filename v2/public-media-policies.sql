-- Dream Space Goa V2: public media bucket for published property listings.
-- Run this in Supabase SQL Editor. Existing private bucket remains private.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ds-v2-public-media','ds-v2-public-media',true,52428800,
  array['image/jpeg','image/png','image/webp','image/avif','video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set public=true, file_size_limit=52428800,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists ds_v2_public_media_read on storage.objects;
create policy ds_v2_public_media_read on storage.objects
for select to anon, authenticated using (bucket_id='ds-v2-public-media');

drop policy if exists ds_v2_public_media_staff_insert on storage.objects;
create policy ds_v2_public_media_staff_insert on storage.objects
for insert to authenticated with check (bucket_id='ds-v2-public-media' and public.ds_v2_is_staff());

drop policy if exists ds_v2_public_media_staff_update on storage.objects;
create policy ds_v2_public_media_staff_update on storage.objects
for update to authenticated using (bucket_id='ds-v2-public-media' and public.ds_v2_is_staff())
with check (bucket_id='ds-v2-public-media' and public.ds_v2_is_staff());

drop policy if exists ds_v2_public_media_staff_delete on storage.objects;
create policy ds_v2_public_media_staff_delete on storage.objects
for delete to authenticated using (bucket_id='ds-v2-public-media' and public.ds_v2_is_staff());
