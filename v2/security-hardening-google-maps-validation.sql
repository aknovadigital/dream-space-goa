-- Dream Space security hardening
-- Validates broker-submitted Google Maps links at the database boundary.
-- This migration is additive: it does not update existing submissions or property records.
-- Apply only after reviewing the matching frontend change in docs/broker.js.

begin;

create or replace function public.ds_v2_validate_submission_google_maps_url()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  maps_url text;
begin
  maps_url := nullif(btrim(new.google_maps_url), '');

  if maps_url is not null
     and maps_url !~* '^https://(maps\.google\.com|maps\.app\.goo\.gl|goo\.gl/maps|www\.google\.com/maps|google\.com/maps)([/?#]|$)' then
    raise exception 'Google Maps link must use an approved HTTPS Google Maps URL.'
      using errcode = '22023';
  end if;

  new.google_maps_url := maps_url;
  return new;
end;
$$;

drop trigger if exists ds_v2_validate_submission_google_maps_url
  on public.ds_v2_property_submissions;

create trigger ds_v2_validate_submission_google_maps_url
before insert or update of google_maps_url
on public.ds_v2_property_submissions
for each row
execute function public.ds_v2_validate_submission_google_maps_url();

commit;
