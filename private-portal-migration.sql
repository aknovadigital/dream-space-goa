-- DREAM SPACE PRIVATE PORTAL: EMAIL OTP VERSION
-- Run this migration in Supabase SQL Editor after the original supabase-setup.sql.
-- If you previously ran private-portal-migration.sql, this upgrades that schema too.
-- Email OTP is the identity check; WhatsApp can still be used to deliver the private URL.

create table if not exists public.client_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  phone text,
  first_name text,
  last_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.client_profiles add column if not exists email text;
alter table public.client_profiles add column if not exists phone text;
alter table public.client_profiles alter column phone drop not null;

create table if not exists public.share_collections (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  recipient_email text,
  recipient_phone text,
  client_name text,
  message text,
  active boolean not null default true,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);
alter table public.share_collections add column if not exists recipient_email text;
alter table public.share_collections add column if not exists recipient_phone text;
alter table public.share_collections alter column recipient_phone drop not null;

create table if not exists public.share_collection_properties (
  collection_id uuid not null references public.share_collections(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (collection_id, property_id)
);

create index if not exists share_collections_email_idx on public.share_collections(lower(recipient_email));
create index if not exists share_collection_properties_property_idx on public.share_collection_properties(property_id);

alter table public.client_profiles enable row level security;
alter table public.share_collections enable row level security;
alter table public.share_collection_properties enable row level security;

-- Public browsing is disabled. Admin access policies from the original setup remain.
drop policy if exists "public reads published properties" on public.properties;
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
      and lower(sc.recipient_email) = lower(auth.jwt() ->> 'email')
      and (sc.expires_at is null or sc.expires_at > now())
  )
);

drop policy if exists "client reads own profile" on public.client_profiles;
create policy "client reads own profile" on public.client_profiles
for select to authenticated
using (id = auth.uid() or public.is_ds_admin());

drop policy if exists "client creates own profile" on public.client_profiles;
create policy "client creates own profile" on public.client_profiles
for insert to authenticated
with check (id = auth.uid() and lower(email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "client updates own profile" on public.client_profiles;
create policy "client updates own profile" on public.client_profiles
for update to authenticated
using (id = auth.uid() and lower(email) = lower(auth.jwt() ->> 'email'))
with check (id = auth.uid() and lower(email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "admin manages client profiles" on public.client_profiles;
create policy "admin manages client profiles" on public.client_profiles
for all to authenticated
using (public.is_ds_admin())
with check (public.is_ds_admin());

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
  and lower(recipient_email) = lower(auth.jwt() ->> 'email')
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
    select 1 from public.share_collections sc
    where sc.id = collection_id
      and sc.active = true
      and lower(sc.recipient_email) = lower(auth.jwt() ->> 'email')
      and (sc.expires_at is null or sc.expires_at > now())
  )
);

grant select, insert, update on public.client_profiles to authenticated;
grant select, insert, update, delete on public.share_collections to authenticated;
grant select, insert, update, delete on public.share_collection_properties to authenticated;
grant select on public.properties to authenticated;

revoke select on public.properties from anon;
revoke all on public.share_collections from anon;
revoke all on public.share_collection_properties from anon;
revoke all on public.client_profiles from anon;
