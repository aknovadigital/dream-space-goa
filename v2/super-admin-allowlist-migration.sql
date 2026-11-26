-- Dream Space Goa: restrict super-admin role to the two owner-approved email addresses.
-- Admins are created manually in Supabase Authentication by the project owner.
-- No OTP or email-verification flow is used by this application.
-- This migration does not create users, set passwords, or delete existing data.

create or replace function public.ds_v2_guard_super_admin_allowlist()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  auth_email text;
  existing_admins integer;
begin
  if new.role <> 'super_admin' then
    return new;
  end if;

  select lower(u.email)
    into auth_email
  from auth.users u
  where u.id = new.id;

  if auth_email is null or auth_email not in (
    'kartikgarg9465@gmail.com',
    'brarbaljinder096@gmail.com'
  ) then
    raise exception 'An allowlisted Auth account is required for a super-admin role.';
  end if;

  if lower(coalesce(new.email, '')) <> auth_email then
    raise exception 'The profile email must match the Auth email.';
  end if;

  select count(*)
    into existing_admins
  from public.ds_v2_profiles p
  where p.role = 'super_admin'
    and p.id <> new.id;

  if existing_admins >= 2 then
    raise exception 'The two authorised super-admin positions are already assigned.';
  end if;

  return new;
end;
$$;

revoke all on function public.ds_v2_guard_super_admin_allowlist() from public;

-- Keep legacy accounts but remove old super-admin privileges outside the allowlist.
update public.ds_v2_profiles
set role = 'team_member', active = false
where role = 'super_admin'
  and lower(coalesce(email, '')) not in (
    'kartikgarg9465@gmail.com',
    'brarbaljinder096@gmail.com'
  );

drop trigger if exists ds_v2_super_admin_allowlist_guard on public.ds_v2_profiles;
create trigger ds_v2_super_admin_allowlist_guard
before insert or update of role, email, id
on public.ds_v2_profiles
for each row
execute function public.ds_v2_guard_super_admin_allowlist();
