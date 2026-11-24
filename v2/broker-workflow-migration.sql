-- Dream Space V2: broker account management and moderated property submissions.
-- Run once in Supabase SQL Editor after schema.sql and broker-visibility-migration.sql.

alter table public.ds_v2_properties
  add column if not exists source_broker_id uuid references public.ds_v2_profiles(id) on delete set null;

create table if not exists public.ds_v2_property_submissions (
  id uuid primary key default gen_random_uuid(),
  broker_id uuid not null references public.ds_v2_profiles(id) on delete cascade,
  title text not null,
  description text,
  location text not null,
  google_maps_url text,
  property_type text not null,
  listing_type text not null check (listing_type in ('sale','rent','commercial_lease')),
  price numeric(14,2),
  bedrooms integer,
  bathrooms integer,
  built_up_area numeric(12,2),
  area_unit text not null default 'sqft',
  features jsonb not null default '[]'::jsonb,
  media jsonb not null default '[]'::jsonb,
  status text not null default 'pending'
    check (status in ('pending','changes_requested','approved','rejected')),
  admin_comment text,
  reviewed_by uuid references public.ds_v2_profiles(id),
  reviewed_at timestamptz,
  approved_property_id uuid references public.ds_v2_properties(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ds_v2_submissions_broker_idx on public.ds_v2_property_submissions(broker_id,created_at desc);
create index if not exists ds_v2_submissions_status_idx on public.ds_v2_property_submissions(status,created_at desc);

alter table public.ds_v2_property_submissions enable row level security;

drop policy if exists ds_v2_submission_broker_read_own on public.ds_v2_property_submissions;
create policy ds_v2_submission_broker_read_own on public.ds_v2_property_submissions
for select to authenticated using (broker_id = auth.uid() and public.ds_v2_is_broker());

drop policy if exists ds_v2_submission_broker_insert_own on public.ds_v2_property_submissions;
create policy ds_v2_submission_broker_insert_own on public.ds_v2_property_submissions
for insert to authenticated with check (broker_id = auth.uid() and public.ds_v2_is_broker() and status = 'pending');

drop policy if exists ds_v2_submission_broker_resubmit on public.ds_v2_property_submissions;
create policy ds_v2_submission_broker_resubmit on public.ds_v2_property_submissions
for update to authenticated
using (broker_id = auth.uid() and public.ds_v2_is_broker() and status in ('pending','changes_requested'))
with check (broker_id = auth.uid() and public.ds_v2_is_broker() and status = 'pending');

drop policy if exists ds_v2_submission_staff_manage on public.ds_v2_property_submissions;
create policy ds_v2_submission_staff_manage on public.ds_v2_property_submissions
for all to authenticated using (public.ds_v2_is_staff()) with check (public.ds_v2_is_staff());

grant select, insert, update on public.ds_v2_property_submissions to authenticated;

-- Brokers may update only their own basic profile fields, never their role/access.
create or replace function public.ds_v2_guard_profile_self_update()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() = old.id and not public.ds_v2_is_admin() then
    if new.role is distinct from old.role
      or new.active is distinct from old.active
      or new.permissions is distinct from old.permissions
      or new.email is distinct from old.email
      or new.id is distinct from old.id then
      raise exception 'You may only update your own name and phone number.';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists ds_v2_profile_self_update_guard on public.ds_v2_profiles;
create trigger ds_v2_profile_self_update_guard
before update on public.ds_v2_profiles
for each row execute function public.ds_v2_guard_profile_self_update();

drop policy if exists ds_v2_profile_self_update on public.ds_v2_profiles;
create policy ds_v2_profile_self_update on public.ds_v2_profiles
for update to authenticated
using (id = auth.uid() and active = true)
with check (id = auth.uid() and active = true);

-- Submission media lives in the existing private ds-v2-property-media bucket.
-- The first folder segment must be the submission UUID and the broker must own that submission.
create or replace function public.ds_v2_can_manage_submission_media(object_name text)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.ds_v2_property_submissions s
    where s.id::text = split_part(object_name,'/',1)
      and s.broker_id = auth.uid()
      and public.ds_v2_is_broker()
      and s.status in ('pending','changes_requested')
  ) or public.ds_v2_is_staff();
$$;
revoke all on function public.ds_v2_can_manage_submission_media(text) from public;
grant execute on function public.ds_v2_can_manage_submission_media(text) to authenticated;

drop policy if exists ds_v2_submission_media_broker_insert on storage.objects;
create policy ds_v2_submission_media_broker_insert on storage.objects
for insert to authenticated
with check (bucket_id='ds-v2-property-media' and public.ds_v2_can_manage_submission_media(name));

drop policy if exists ds_v2_submission_media_broker_read on storage.objects;
create policy ds_v2_submission_media_broker_read on storage.objects
for select to authenticated
using (bucket_id='ds-v2-property-media' and public.ds_v2_can_manage_submission_media(name));

drop policy if exists ds_v2_submission_media_broker_delete on storage.objects;
create policy ds_v2_submission_media_broker_delete on storage.objects
for delete to authenticated
using (bucket_id='ds-v2-property-media' and public.ds_v2_can_manage_submission_media(name));

-- Staff media policies already exist in storage-policies.sql.

-- Protect submission review fields from broker-side edits.
create or replace function public.ds_v2_guard_broker_submission_update()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() = old.broker_id and not public.ds_v2_is_staff() then
    if old.status not in ('pending','changes_requested')
      or new.broker_id is distinct from old.broker_id
      or new.status <> 'pending'
      or new.admin_comment is distinct from old.admin_comment
      or new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at
      or new.approved_property_id is distinct from old.approved_property_id
      or new.created_at is distinct from old.created_at then
      raise exception 'Only resubmission of your own pending or changes-requested property is allowed.';
    end if;
    if old.status = 'pending' and (to_jsonb(new) - 'media' - 'updated_at') is distinct from (to_jsonb(old) - 'media' - 'updated_at') then
      raise exception 'A pending submission cannot be edited unless the admin requests changes.';
    end if;
  end if;
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists ds_v2_submission_update_guard on public.ds_v2_property_submissions;
create trigger ds_v2_submission_update_guard before update on public.ds_v2_property_submissions
for each row execute function public.ds_v2_guard_broker_submission_update();
