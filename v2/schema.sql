-- Dream Space Goa V2 schema
-- Safe additive migration: all objects are prefixed ds_v2_.
-- Does not drop, rename, or alter legacy tables/policies.
create extension if not exists pgcrypto;

create table if not exists public.ds_v2_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text,
  phone text,
  role text not null default 'team_member'
    check (role in ('super_admin','team_member','broker')),
  permissions jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.ds_v2_properties (
  id uuid primary key default gen_random_uuid(),
  property_code text unique,
  title text not null,
  slug text unique,
  location text not null,
  area text,
  property_type text not null default 'Apartment',
  listing_type text not null check (listing_type in ('sale','rent','commercial_lease')),
  inventory_category text not null default 'private'
    check (inventory_category in ('public','broker','exclusive','private')),
  price numeric(14,2),
  currency text not null default 'INR',
  bedrooms integer,
  bathrooms integer,
  built_up_area numeric(12,2),
  area_unit text not null default 'sqft',
  description text,
  features jsonb not null default '[]'::jsonb,
  media jsonb not null default '[]'::jsonb,
  owner_name text,
  owner_phone text,
  owner_email text,
  availability text not null default 'available'
    check (availability in ('available','under_offer','sold','rented','unavailable','upcoming')),
  commission_amount numeric(14,2),
  internal_notes text,
  created_by uuid references public.ds_v2_profiles(id),
  updated_by uuid references public.ds_v2_profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ds_v2_leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text not null,
  email text,
  source text not null default 'website',
  requirement_type text check (requirement_type in ('sale','rent','commercial_lease')),
  property_type text,
  preferred_locations text[] not null default '{}',
  budget_min numeric(14,2),
  budget_max numeric(14,2),
  bedrooms integer,
  status text not null default 'new'
    check (status in ('new','contacted','interested','site_visit_scheduled','negotiation','deal_closed','not_interested')),
  assigned_to uuid references public.ds_v2_profiles(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ds_v2_followups (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.ds_v2_leads(id) on delete set null,
  property_id uuid references public.ds_v2_properties(id) on delete set null,
  assigned_to uuid references public.ds_v2_profiles(id),
  followup_type text not null default 'call' check (followup_type in ('call','meeting','site_visit','other')),
  due_at timestamptz not null,
  notes text,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.ds_v2_deals (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references public.ds_v2_properties(id) on delete set null,
  lead_id uuid references public.ds_v2_leads(id) on delete set null,
  client_name text not null,
  owner_name text,
  final_amount numeric(14,2) not null default 0,
  brokerage_amount numeric(14,2) not null default 0,
  closing_date date,
  payment_status text not null default 'pending'
    check (payment_status in ('pending','partial','paid')),
  remarks text,
  created_at timestamptz not null default now()
);

create table if not exists public.ds_v2_property_brokers (
  property_id uuid not null references public.ds_v2_properties(id) on delete cascade,
  broker_id uuid not null references public.ds_v2_profiles(id) on delete cascade,
  shared_at timestamptz not null default now(),
  primary key (property_id, broker_id)
);

create table if not exists public.ds_v2_client_shares (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.ds_v2_properties(id) on delete cascade,
  client_name text,
  client_email text,
  token_hash text not null unique,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_by uuid references public.ds_v2_profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists ds_v2_properties_public_idx
  on public.ds_v2_properties (inventory_category, availability, listing_type, location);
create index if not exists ds_v2_leads_status_idx on public.ds_v2_leads (status, created_at desc);
create index if not exists ds_v2_followups_due_idx on public.ds_v2_followups (due_at) where completed_at is null;
create index if not exists ds_v2_deals_closing_idx on public.ds_v2_deals (closing_date desc);

create or replace function public.ds_v2_is_staff()
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.ds_v2_profiles p
    where p.id = auth.uid() and p.active = true and p.role in ('super_admin','team_member')
  );
$$;

create or replace function public.ds_v2_is_admin()
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.ds_v2_profiles p
    where p.id = auth.uid() and p.active = true and p.role = 'super_admin'
  );
$$;

revoke all on function public.ds_v2_is_staff() from public;
revoke all on function public.ds_v2_is_admin() from public;
grant execute on function public.ds_v2_is_staff() to authenticated;
grant execute on function public.ds_v2_is_admin() to authenticated;

alter table public.ds_v2_profiles enable row level security;
alter table public.ds_v2_properties enable row level security;
alter table public.ds_v2_leads enable row level security;
alter table public.ds_v2_followups enable row level security;
alter table public.ds_v2_deals enable row level security;
alter table public.ds_v2_property_brokers enable row level security;
alter table public.ds_v2_client_shares enable row level security;

drop policy if exists ds_v2_profile_self_or_admin on public.ds_v2_profiles;
create policy ds_v2_profile_self_or_admin on public.ds_v2_profiles
for select to authenticated using (id = auth.uid() or public.ds_v2_is_admin());
drop policy if exists ds_v2_admin_manage_profiles on public.ds_v2_profiles;
create policy ds_v2_admin_manage_profiles on public.ds_v2_profiles
for all to authenticated using (public.ds_v2_is_admin()) with check (public.ds_v2_is_admin());

drop policy if exists ds_v2_public_property_read on public.ds_v2_properties;
create policy ds_v2_public_property_read on public.ds_v2_properties
for select to anon, authenticated using (
  inventory_category = 'public' and availability in ('available','under_offer')
);
drop policy if exists ds_v2_staff_all_properties on public.ds_v2_properties;
create policy ds_v2_staff_all_properties on public.ds_v2_properties
for all to authenticated using (public.ds_v2_is_staff()) with check (public.ds_v2_is_staff());
drop policy if exists ds_v2_broker_assigned_properties on public.ds_v2_properties;
create policy ds_v2_broker_assigned_properties on public.ds_v2_properties
for select to authenticated using (
  exists (select 1 from public.ds_v2_property_brokers pb
    where pb.property_id = id and pb.broker_id = auth.uid())
);

drop policy if exists ds_v2_public_lead_insert on public.ds_v2_leads;
create policy ds_v2_public_lead_insert on public.ds_v2_leads
for insert to anon, authenticated with check (source = 'website');
drop policy if exists ds_v2_staff_manage_leads on public.ds_v2_leads;
create policy ds_v2_staff_manage_leads on public.ds_v2_leads
for all to authenticated using (public.ds_v2_is_staff()) with check (public.ds_v2_is_staff());

drop policy if exists ds_v2_staff_manage_followups on public.ds_v2_followups;
create policy ds_v2_staff_manage_followups on public.ds_v2_followups
for all to authenticated using (public.ds_v2_is_staff()) with check (public.ds_v2_is_staff());
drop policy if exists ds_v2_staff_manage_deals on public.ds_v2_deals;
create policy ds_v2_staff_manage_deals on public.ds_v2_deals
for all to authenticated using (public.ds_v2_is_staff()) with check (public.ds_v2_is_staff());
drop policy if exists ds_v2_staff_manage_broker_shares on public.ds_v2_property_brokers;
create policy ds_v2_staff_manage_broker_shares on public.ds_v2_property_brokers
for all to authenticated using (public.ds_v2_is_staff()) with check (public.ds_v2_is_staff());
drop policy if exists ds_v2_broker_read_own_shares on public.ds_v2_property_brokers;
create policy ds_v2_broker_read_own_shares on public.ds_v2_property_brokers
for select to authenticated using (broker_id = auth.uid());
drop policy if exists ds_v2_staff_manage_client_shares on public.ds_v2_client_shares;
create policy ds_v2_staff_manage_client_shares on public.ds_v2_client_shares
for all to authenticated using (public.ds_v2_is_staff()) with check (public.ds_v2_is_staff());

-- Bootstrap the first super admin after creating their Supabase Auth user:
-- insert into public.ds_v2_profiles (id, full_name, email, role)
-- values ('AUTH-USER-UUID', 'Admin Name', 'admin@example.com', 'super_admin');
