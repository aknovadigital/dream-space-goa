-- Broker applications, operation area, and safe broker access.
-- Additive only. Does not delete existing records.

alter table public.ds_v2_profiles
  add column if not exists area_of_operation text;

create table if not exists public.ds_v2_broker_applications (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(trim(full_name)) between 2 and 100),
  area_of_operation text not null check (length(trim(area_of_operation)) between 2 and 160),
  email text not null,
  phone text not null,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  admin_note text,
  reviewed_by uuid references public.ds_v2_profiles(id),
  reviewed_at timestamptz,
  profile_id uuid references public.ds_v2_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists ds_v2_broker_app_email_pending_unique
  on public.ds_v2_broker_applications (lower(email))
  where status = 'pending';
create index if not exists ds_v2_broker_app_status_created_idx
  on public.ds_v2_broker_applications(status, created_at desc);

alter table public.ds_v2_broker_applications enable row level security;
revoke all on public.ds_v2_broker_applications from anon, authenticated;
grant select, update on public.ds_v2_broker_applications to authenticated;

drop policy if exists ds_v2_broker_app_admin_read on public.ds_v2_broker_applications;
create policy ds_v2_broker_app_admin_read on public.ds_v2_broker_applications
for select to authenticated using (public.ds_v2_is_admin());
drop policy if exists ds_v2_broker_app_admin_update on public.ds_v2_broker_applications;
create policy ds_v2_broker_app_admin_update on public.ds_v2_broker_applications
for update to authenticated using (public.ds_v2_is_admin()) with check (public.ds_v2_is_admin());

-- Ensure broker roles cannot read the legacy "broker" inventory category.
drop policy if exists ds_v2_broker_all_inventory on public.ds_v2_properties;
drop policy if exists ds_v2_broker_assigned_properties on public.ds_v2_properties;
create policy ds_v2_broker_assigned_properties on public.ds_v2_properties
for select to authenticated using (
  public.ds_v2_is_broker()
  and inventory_category = 'exclusive'
  and availability in ('available','under_offer')
  and exists (
    select 1 from public.ds_v2_property_brokers pb
    where pb.property_id = ds_v2_properties.id and pb.broker_id = auth.uid()
  )
);

-- Restrict the broker inventory UI and underlying access to assigned exclusive properties.
create or replace function public.ds_v2_can_view_property_media(object_name text)
returns boolean language sql stable security definer set search_path=public as $$
  select exists (
    select 1 from public.ds_v2_properties p
    where p.id::text = split_part(object_name, '/', 1)
      and p.availability in ('available','under_offer')
      and (
        (public.ds_v2_is_broker() and p.inventory_category='exclusive'
          and exists (select 1 from public.ds_v2_property_brokers pb
            where pb.property_id=p.id and pb.broker_id=auth.uid()))
        or public.ds_v2_is_staff()
      )
  );
$$;
revoke all on function public.ds_v2_can_view_property_media(text) from public;
grant execute on function public.ds_v2_can_view_property_media(text) to authenticated;
