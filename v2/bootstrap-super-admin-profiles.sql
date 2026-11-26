-- Dream Space Goa: create the two owner-approved super-admin profiles.
-- First create both users manually in Supabase Dashboard -> Authentication -> Users.
-- Set their passwords there. No OTP, email delivery, or verification flow is used.
-- This script does not create Auth users, set passwords, or delete existing data.

do $$
declare
  expected_count integer;
begin
  select count(*) into expected_count
  from auth.users
  where lower(email) in ('kartikgarg9465@gmail.com', 'brarbaljinder096@gmail.com');

  if expected_count <> 2 then
    raise exception 'Create both approved admin Auth users first: kartikgarg9465@gmail.com and brarbaljinder096@gmail.com.';
  end if;

  if exists (
    select 1
    from public.ds_v2_profiles p
    where p.role = 'super_admin'
      and lower(coalesce(p.email, '')) not in ('kartikgarg9465@gmail.com', 'brarbaljinder096@gmail.com')
  ) then
    raise exception 'An old non-allowlisted super-admin profile exists. Review it manually before proceeding; this script will not delete or demote it.';
  end if;
end $$;

insert into public.ds_v2_profiles (id, full_name, email, role, active, permissions)
select
  u.id,
  coalesce(nullif(u.raw_user_meta_data->>'full_name', ''), split_part(u.email, '@', 1)),
  lower(u.email),
  'super_admin',
  true,
  '{}'::jsonb
from auth.users u
where lower(u.email) in ('kartikgarg9465@gmail.com', 'brarbaljinder096@gmail.com')
on conflict (id) do update
set
  email = excluded.email,
  role = 'super_admin',
  active = true;

select id, full_name, email, role, active
from public.ds_v2_profiles
where lower(email) in ('kartikgarg9465@gmail.com', 'brarbaljinder096@gmail.com')
order by lower(email);