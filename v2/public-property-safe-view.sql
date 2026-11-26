-- Public-safe property view: never expose owner contacts, commission or internal notes to anonymous visitors.
create or replace view public.ds_v2_public_properties
with (security_barrier = true)
as
select id, property_code, title, slug, location, area, property_type, listing_type,
       inventory_category, price, currency, bedrooms, bathrooms, built_up_area,
       area_unit, description, features, media, availability, created_at, updated_at
from public.ds_v2_properties
where inventory_category = 'public'
  and availability in ('available','under_offer');

revoke all on public.ds_v2_properties from anon;
grant select on public.ds_v2_public_properties to anon, authenticated;
