alter table public.ds_v2_properties add column if not exists assigned_to uuid references public.ds_v2_profiles(id) on delete set null;
create index if not exists ds_v2_properties_assigned_to_idx on public.ds_v2_properties (assigned_to);
