-- DREAM SPACE PRIVATE, INVITATION-ONLY PROPERTY PORTAL
-- Run AFTER the original supabase-setup.sql.
-- Existing admin profiles and properties are retained.
-- This migration disables public property browsing.

create table if not exists public.client_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text not null unique,
  first_name text,
  last_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.share_collections (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  recipient_phone text not null,
  recipient_email text,
  client_name text,
  message text,
  active boolean not null default true,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table if not exists public.share_collection_properties (
  collection_id uuid not null references public.share_collections(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (collection_id, property_id)
);

create index if not exists share_collections_phone_idx on public.share_collections(recipient_phone);
create index if not exists share_collection_properties_property_idx on public.share_collection_properties(property_id);

alter table public.client_profiles enable row level security;
alter table public.share_collections enable row level security;
alter table public.share_collection_properties enable row level security;

-- Remove the old public property listing policy.
drop policy if exists "public reads published properties" on public.properties;

-- Clients can read only their own verified profile; admins can read all.
drop policy if exists "client reads own profile" on public.client_profiles;
create policy "client reads own profile" on public.client_profiles
for select to authenticated
using (id = auth.uid() or public.is_ds_admin());

drop policy if exists "client creates own profile" on public.client_profiles;
create policy "client creates own profile" on public.client_profiles
for insert to authenticated
with check (id = auth.uid() and phone = (auth.jwt() ->> 'phone'));

drop policy if exists "client updates own profile" on public.client_profiles;
create policy "client updates own profile" on public.client_profiles
for update to authenticated
using (id = auth.uid() and phone = (auth.jwt() ->> 'phone'))
with check (id = auth.uid() and phone = (auth.jwt() ->> 'phone'));

drop policy if exists "admin manages client profiles" on public.client_profiles;
create policy "admin manages client profiles" on public.client_profiles
for all to authenticated
using (public.is_ds_admin())
with check (public.is_ds_admin());

-- Admins manage collections. A client can read only an active, unexpired
-- collection addressed to the phone number verified in their Supabase OTP session.
drop policy if exists "admin manages share collections" on public.share_collections;
create policy "admin manages share collections" on public.share_collections
for all to authenticated
using (public.is_ds_admin())
with check (public.is_ds_admin());

drop policy if exists "recipient reads own share collections" on public.share_collections;
create policy "recipient reads own share collections" on public.share_collections
for select to authenticated
using (
  active = true
  and recipient_phone = (auth.jwt() ->> 'phone')
  and (expires_at is null or expires_at > now())
);

drop policy if exists "admin manages collection properties" on public.share_collection_properties;
create policy "admin manages collection properties" on public.share_collection_properties
for all to authenticated
using (public.is_ds_admin())
with check (public.is_ds_admin());

drop policy if exists "recipient reads shared collection properties" on public.share_collection_properties;
create policy "recipient reads shared collection properties" on public.share_collection_properties
for select to authenticated
using (
  exists (
    select 1
    from public.share_collections sc
    where sc.id = collection_id
      and sc.active = true
      and sc.recipient_phone = (auth.jwt() ->> 'phone')
      and (sc.expires_at is null or sc.expires_at > now())
  )
);

-- Replace property read access: admin OR property included in a collection
-- addressed to the currently OTP-verified phone number.
drop policy if exists "client reads only shared properties" on public.properties;
create policy "client reads only shared properties" on public.properties
for select to authenticated
using (
  public.is_ds_admin()
  or exists (
    select 1
    from public.share_collection_properties scp
    join public.share_collections sc on sc.id = scp.collection_id
    where scp.property_id = properties.id
      and sc.active = true
      and sc.recipient_phone = (auth.jwt() ->> 'phone')
      and (sc.expires_at is null or sc.expires_at > now())
  )
);

grant select, insert, update on public.client_profiles to authenticated;
grant select, insert, update, delete on public.share_collections to authenticated;
grant select, insert, update, delete on public.share_collection_properties to authenticated;
grant select on public.properties to authenticated;

-- Public users must not be able to browse properties or private share collections.
revoke select on public.properties from anon;
revoke all on public.share_collections from anon;
revoke all on public.share_collection_properties from anon;
revoke all on public.client_profiles from anon;

-- Existing admin full CRUD policies remain in force. This migration does not
-- expose any service-role key or permit clients to create/modify collections.
