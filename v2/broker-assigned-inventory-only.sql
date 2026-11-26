-- Dream Space Goa: restrict broker inventory to public + specifically allotted exclusive properties.
-- Apply after v2/broker-visibility-migration.sql.
-- Does not delete data or change the website schema.

-- Remove the previous policy that exposed every broker-category listing to every broker.
drop policy if exists ds_v2_broker_all_inventory on public.ds_v2_properties;

-- Brokers may read public listings (the existing ds_v2_public_property_read policy handles these)
-- and exclusive listings only when an assignment exists for their own auth user.
drop policy if exists ds_v2_broker_assigned_properties on public.ds_v2_properties;
create policy ds_v2_broker_assigned_properties on public.ds_v2_properties
for select to authenticated
using (
  public.ds_v2_is_broker()
  and inventory_category = 'exclusive'
  and availability in ('available','under_offer')
  and exists (
    select 1
    from public.ds_v2_property_brokers pb
    where pb.property_id = ds_v2_properties.id
      and pb.broker_id = auth.uid()
  )
);

-- The private media policy follows the same rule: no general broker-category access.
create or replace function public.ds_v2_can_view_property_media(object_name text)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.ds_v2_properties p
    where p.id::text = split_part(object_name, '/', 1)
      and p.availability in ('available','under_offer')
      and (
        (public.ds_v2_is_broker()
          and p.inventory_category = 'exclusive'
          and exists (
            select 1 from public.ds_v2_property_brokers pb
            where pb.property_id = p.id and pb.broker_id = auth.uid()
          ))
        or public.ds_v2_is_staff()
      )
  );
$$;

revoke all on function public.ds_v2_can_view_property_media(text) from public;
grant execute on function public.ds_v2_can_view_property_media(text) to authenticated;