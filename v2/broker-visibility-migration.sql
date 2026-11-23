-- Dream Space Goa broker visibility migration
-- Run after v2/schema.sql. Safe additive migration.
create or replace function public.ds_v2_is_broker()
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.ds_v2_profiles p
    where p.id = auth.uid() and p.active = true and p.role = 'broker'
  );
$$;
revoke all on function public.ds_v2_is_broker() from public;
grant execute on function public.ds_v2_is_broker() to authenticated;

drop policy if exists ds_v2_broker_all_inventory on public.ds_v2_properties;
create policy ds_v2_broker_all_inventory on public.ds_v2_properties
for select to authenticated
using (
  public.ds_v2_is_broker()
  and inventory_category = 'broker'
  and availability in ('available','under_offer')
);

drop policy if exists ds_v2_broker_assigned_properties on public.ds_v2_properties;
create policy ds_v2_broker_assigned_properties on public.ds_v2_properties
for select to authenticated
using (
  public.ds_v2_is_broker()
  and inventory_category = 'exclusive'
  and exists (
    select 1 from public.ds_v2_property_brokers pb
    where pb.property_id = ds_v2_properties.id and pb.broker_id = auth.uid()
  )
  and availability in ('available','under_offer')
);
