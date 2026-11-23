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

-- Allow brokers to read only the media belonging to inventory they can view.
-- Broker media stays in the private bucket; generated URLs are short-lived.
create or replace function public.ds_v2_can_view_property_media(object_name text)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.ds_v2_properties p
    where p.id::text = split_part(object_name, '/', 1)
      and p.availability in ('available','under_offer')
      and (
        (public.ds_v2_is_broker() and p.inventory_category = 'broker')
        or
        (public.ds_v2_is_broker() and p.inventory_category = 'exclusive'
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

drop policy if exists ds_v2_media_broker_read_assigned on storage.objects;
create policy ds_v2_media_broker_read_assigned on storage.objects
for select to authenticated
using (
  bucket_id = 'ds-v2-property-media'
  and public.ds_v2_can_view_property_media(name)
);
