-- DREAM SPACE GOA CRM: run this entire file in Supabase SQL Editor.
-- 1) Create tables
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  role text not null default 'admin' check (role in ('admin'))
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  location text not null,
  property_type text not null default 'Apartment',
  listing_type text not null default 'sale' check (listing_type in ('sale','rent','commercial')),
  price numeric,
  price_label text,
  bedrooms integer,
  bathrooms integer,
  area text,
  description text,
  features text[] not null default '{}',
  images text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft','published','sold','rented','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inquiries (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  phone text not null,
  email text,
  interest text,
  preferred_location text,
  message text,
  property_id uuid references public.properties(id) on delete set null,
  source text not null default 'website',
  status text not null default 'new' check (status in ('new','contacted','interested','site_visit','negotiation','closed','lost')),
  admin_notes text,
  next_follow_up timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2) Admin-check helper. Only a user whose UUID is in profiles can administer data.
create or replace function public.is_ds_admin()
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;
revoke all on function public.is_ds_admin() from public;
grant execute on function public.is_ds_admin() to authenticated;

-- 3) Enable row-level security
alter table public.profiles enable row level security;
alter table public.properties enable row level security;
alter table public.inquiries enable row level security;

drop policy if exists "admin reads own profile" on public.profiles;
create policy "admin reads own profile" on public.profiles for select to authenticated using (id = auth.uid());

drop policy if exists "public reads published properties" on public.properties;
create policy "public reads published properties" on public.properties for select to anon, authenticated using (status = 'published' or public.is_ds_admin());

drop policy if exists "admin manages properties" on public.properties;
create policy "admin manages properties" on public.properties for all to authenticated using (public.is_ds_admin()) with check (public.is_ds_admin());

drop policy if exists "visitors submit inquiries" on public.inquiries;
create policy "visitors submit inquiries" on public.inquiries for insert to anon, authenticated with check (
  length(trim(customer_name)) > 0 and length(trim(phone)) > 0
);

drop policy if exists "admin reads inquiries" on public.inquiries;
create policy "admin reads inquiries" on public.inquiries for select to authenticated using (public.is_ds_admin());

drop policy if exists "admin updates inquiries" on public.inquiries;
create policy "admin updates inquiries" on public.inquiries for update to authenticated using (public.is_ds_admin()) with check (public.is_ds_admin());

drop policy if exists "admin deletes inquiries" on public.inquiries;
create policy "admin deletes inquiries" on public.inquiries for delete to authenticated using (public.is_ds_admin());

grant select on public.properties to anon, authenticated;
grant insert on public.inquiries to anon, authenticated;
grant select, insert, update, delete on public.properties to authenticated;
grant select, update, delete on public.inquiries to authenticated;
grant select on public.profiles to authenticated;

-- 4) Storage bucket for property images
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('property-images', 'property-images', true, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "public views property photos" on storage.objects;
create policy "public views property photos" on storage.objects for select to anon, authenticated using (bucket_id = 'property-images');

drop policy if exists "admin uploads property photos" on storage.objects;
create policy "admin uploads property photos" on storage.objects for insert to authenticated with check (bucket_id = 'property-images' and public.is_ds_admin());

drop policy if exists "admin updates property photos" on storage.objects;
create policy "admin updates property photos" on storage.objects for update to authenticated using (bucket_id = 'property-images' and public.is_ds_admin()) with check (bucket_id = 'property-images' and public.is_ds_admin());

drop policy if exists "admin deletes property photos" on storage.objects;
create policy "admin deletes property photos" on storage.objects for delete to authenticated using (bucket_id = 'property-images' and public.is_ds_admin());

-- 5) IMPORTANT: create your owner account first in Supabase Authentication > Users.
-- Then copy that user's UUID and run this separately, replacing the two placeholders:
-- insert into public.profiles (id, email, role)
-- values ('YOUR-AUTH-USER-UUID', 'YOUR-LOGIN-EMAIL', 'admin');
