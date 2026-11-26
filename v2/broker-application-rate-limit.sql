-- Server-side application throttling state; no direct browser access.
create table if not exists public.ds_v2_broker_application_rate (
  id bigint generated always as identity primary key,
  email text not null,
  phone text not null,
  created_at timestamptz not null default now()
);
create index if not exists ds_v2_broker_app_rate_created_idx
  on public.ds_v2_broker_application_rate(created_at);
alter table public.ds_v2_broker_application_rate enable row level security;
revoke all on public.ds_v2_broker_application_rate from anon, authenticated;
