-- Dream Space Goa V2 private media bucket policies.
-- Run after creating the private bucket ds-v2-property-media.
-- Only active staff (super_admin/team_member) can upload, read, update or delete media.
drop policy if exists ds_v2_media_staff_read on storage.objects;
create policy ds_v2_media_staff_read on storage.objects
for select to authenticated
using (bucket_id = 'ds-v2-property-media' and public.ds_v2_is_staff());

drop policy if exists ds_v2_media_staff_insert on storage.objects;
create policy ds_v2_media_staff_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'ds-v2-property-media' and public.ds_v2_is_staff());

drop policy if exists ds_v2_media_staff_update on storage.objects;
create policy ds_v2_media_staff_update on storage.objects
for update to authenticated
using (bucket_id = 'ds-v2-property-media' and public.ds_v2_is_staff())
with check (bucket_id = 'ds-v2-property-media' and public.ds_v2_is_staff());

drop policy if exists ds_v2_media_staff_delete on storage.objects;
create policy ds_v2_media_staff_delete on storage.objects
for delete to authenticated
using (bucket_id = 'ds-v2-property-media' and public.ds_v2_is_staff());
