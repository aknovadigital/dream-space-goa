-- Dream Space Goa: create the two owner-approved super-admin profiles.
-- Run only AFTER both Auth users exist and their email addresses are verified.
-- This script does not create Auth users, set passwords, or delete any records.

do $$
declare
  expected_count integer;
  verified_count integer;
begin
  select count(*) into expected_count
  from auth.users
  where lower(email) in ('kartikgarg9465@gmail.com', 'brarbaljinder096@gmail.com');

  select count(*) into verified_count
  from auth.users
  where lower(email) in ('kartikgarg9465@gmail.com', 'brarbaljinder096@gmail.com')
    and email_confirmed_at is not null;

  if expected_count <> 2 or verified_count <> 2 then
    raise exception 'Both approved admin Auth users must exist and have verified email addresses before running this setup.';
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
  and u.email_confirmed_at is not null
on conflict (id) do update
set
  email = excluded.email,
  role = 'super_admin',
  active = true;

-- Verify the resulting administrator profiles.
select id, full_name, email, role, active
from public.ds_v2_profiles
where lower(email) in ('kartikgarg9465@gmail.com', 'brarbaljinder096@gmail.com')
order by lower(email);
