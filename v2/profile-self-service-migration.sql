-- Dream Space Goa: secure self-service profile editing
-- Run once in Supabase SQL Editor after deploying the portal changes.

-- Allow every signed-in user to update their own profile row.
-- The existing super-admin policy continues to allow admins to manage other profiles.
drop policy if exists ds_v2_profile_self_update on public.ds_v2_profiles;
create policy ds_v2_profile_self_update
on public.ds_v2_profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- A user may only change their own display name and phone through self-service.
-- Login email, role, activation status, permissions and identity remain protected.
create or replace function public.ds_v2_protect_self_profile_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() = old.id then
    if new.id is distinct from old.id
      or new.email is distinct from old.email
      or new.role is distinct from old.role
      or new.active is distinct from old.active
      or new.permissions is distinct from old.permissions
      or new.created_at is distinct from old.created_at then
      raise exception 'You can only update your own name and mobile number. Contact an administrator to change protected account details.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists ds_v2_profiles_protect_self_fields on public.ds_v2_profiles;
create trigger ds_v2_profiles_protect_self_fields
before update on public.ds_v2_profiles
for each row
execute function public.ds_v2_protect_self_profile_fields();
