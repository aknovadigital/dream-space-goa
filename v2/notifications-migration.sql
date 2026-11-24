-- Dream Space in-portal notifications and website interaction events.
-- Additive migration. Run in Supabase SQL Editor after the existing V2 migrations.

create table if not exists public.ds_v2_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.ds_v2_profiles(id) on delete cascade,
  title text not null,
  message text not null default '',
  entity_type text,
  entity_id uuid,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists ds_v2_notifications_user_created_idx
  on public.ds_v2_notifications(user_id, created_at desc);
create index if not exists ds_v2_notifications_unread_idx
  on public.ds_v2_notifications(user_id, created_at desc) where read_at is null;
alter table public.ds_v2_notifications enable row level security;

drop policy if exists ds_v2_notifications_read_own on public.ds_v2_notifications;
create policy ds_v2_notifications_read_own on public.ds_v2_notifications
for select to authenticated using (user_id = auth.uid() or public.ds_v2_is_staff());
drop policy if exists ds_v2_notifications_update_own on public.ds_v2_notifications;
create policy ds_v2_notifications_update_own on public.ds_v2_notifications
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, update on public.ds_v2_notifications to authenticated;

create table if not exists public.ds_v2_site_interactions (
  id uuid primary key default gen_random_uuid(),
  interaction_type text not null check (interaction_type in ('whatsapp_click','call_click')),
  property_id uuid references public.ds_v2_properties(id) on delete set null,
  page_path text,
  created_at timestamptz not null default now()
);
alter table public.ds_v2_site_interactions enable row level security;
drop policy if exists ds_v2_site_interactions_public_insert on public.ds_v2_site_interactions;
create policy ds_v2_site_interactions_public_insert on public.ds_v2_site_interactions
for insert to anon, authenticated with check (true);
drop policy if exists ds_v2_site_interactions_staff_read on public.ds_v2_site_interactions;
create policy ds_v2_site_interactions_staff_read on public.ds_v2_site_interactions
for select to authenticated using (public.ds_v2_is_staff());
grant insert on public.ds_v2_site_interactions to anon, authenticated;
grant select on public.ds_v2_site_interactions to authenticated;

create or replace function public.ds_v2_notify_staff(
  p_title text, p_message text, p_entity_type text default null, p_entity_id uuid default null
) returns void language plpgsql security definer set search_path=public as $$
begin
  insert into public.ds_v2_notifications(user_id,title,message,entity_type,entity_id)
  select id,p_title,p_message,p_entity_type,p_entity_id
  from public.ds_v2_profiles where active=true and role in ('super_admin','team_member');
end; $$;
revoke all on function public.ds_v2_notify_staff(text,text,text,uuid) from public;

create or replace function public.ds_v2_notify_submission_insert()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform public.ds_v2_notify_staff('New property submission',
    'A broker submitted a property for admin review.', 'submission', new.id);
  return new;
end; $$;
drop trigger if exists ds_v2_submission_notify_staff on public.ds_v2_property_submissions;
create trigger ds_v2_submission_notify_staff after insert on public.ds_v2_property_submissions
for each row execute function public.ds_v2_notify_submission_insert();

create or replace function public.ds_v2_notify_new_website_lead()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.source='website' then
    perform public.ds_v2_notify_staff('New website enquiry',
      'A visitor submitted a new enquiry through the website.', 'lead', new.id);
  end if;
  return new;
end; $$;
drop trigger if exists ds_v2_lead_notify_staff on public.ds_v2_leads;
create trigger ds_v2_lead_notify_staff after insert on public.ds_v2_leads
for each row execute function public.ds_v2_notify_new_website_lead();

create or replace function public.ds_v2_notify_site_interaction()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.interaction_type='whatsapp_click' then
    perform public.ds_v2_notify_staff('WhatsApp button clicked',
      'A visitor clicked a WhatsApp contact button on the website.', 'interaction', new.id);
  else
    perform public.ds_v2_notify_staff('Call button clicked',
      'A visitor clicked a Call Now button on the website.', 'interaction', new.id);
  end if;
  return new;
end; $$;
drop trigger if exists ds_v2_interaction_notify_staff on public.ds_v2_site_interactions;
create trigger ds_v2_interaction_notify_staff after insert on public.ds_v2_site_interactions
for each row execute function public.ds_v2_notify_site_interaction();

create or replace function public.ds_v2_notify_broker_property_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  broker record;
  changed boolean := false;
begin
  if tg_op='INSERT' then
    changed := true;
  else
    changed := (new.title is distinct from old.title)
      or (new.location is distinct from old.location)
      or (new.price is distinct from old.price)
      or (new.availability is distinct from old.availability)
      or (new.description is distinct from old.description)
      or (new.media is distinct from old.media);
  end if;
  if not changed then return new; end if;

  if new.inventory_category='broker' then
    for broker in select id from public.ds_v2_profiles where active=true and role='broker'
    loop
      insert into public.ds_v2_notifications(user_id,title,message,entity_type,entity_id)
      values (broker.id, case when tg_op='INSERT' then 'New property available' else 'Property updated' end,
        case when tg_op='INSERT' then 'A new property has been added to your property list.' else 'A property in your list has been updated.' end,
        'property',new.id);
    end loop;
  elsif new.inventory_category='exclusive' then
    -- Recipient-specific assignment; notification wording does not reveal exclusivity.
    insert into public.ds_v2_notifications(user_id,title,message,entity_type,entity_id)
    select pb.broker_id,
      case when tg_op='INSERT' then 'New property available' else 'Property updated' end,
      case when tg_op='INSERT' then 'A new property has been added to your property list.' else 'A property in your list has been updated.' end,
      'property',new.id
    from public.ds_v2_property_brokers pb
    join public.ds_v2_profiles p on p.id=pb.broker_id and p.active=true
    where pb.property_id=new.id;
  end if;
  return new;
end; $$;
drop trigger if exists ds_v2_property_notify_brokers on public.ds_v2_properties;
create trigger ds_v2_property_notify_brokers
after insert or update of title,location,price,availability,description,media,inventory_category
on public.ds_v2_properties for each row execute function public.ds_v2_notify_broker_property_change();

create or replace function public.ds_v2_notify_broker_assignment()
returns trigger language plpgsql security definer set search_path=public as $$
declare p public.ds_v2_properties%rowtype;
begin
  select * into p from public.ds_v2_properties where id=new.property_id;
  if p.id is not null and p.inventory_category='exclusive' then
    insert into public.ds_v2_notifications(user_id,title,message,entity_type,entity_id)
    select new.broker_id,'New property available',
      'A new property has been added to your property list.','property',new.property_id
    where exists(select 1 from public.ds_v2_profiles where id=new.broker_id and active=true);
  end if;
  return new;
end; $$;
drop trigger if exists ds_v2_broker_assignment_notify on public.ds_v2_property_brokers;
create trigger ds_v2_broker_assignment_notify after insert on public.ds_v2_property_brokers
for each row execute function public.ds_v2_notify_broker_assignment();

-- Notify a broker when the review status of their own submission changes.
create or replace function public.ds_v2_notify_submission_broker()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status is distinct from old.status then
    insert into public.ds_v2_notifications(user_id,title,message,entity_type,entity_id)
    values(new.broker_id,
      case new.status when 'approved' then 'Property submission approved'
        when 'changes_requested' then 'Changes requested on your submission'
        when 'rejected' then 'Property submission not approved'
        else 'Submission status updated' end,
      'Your submitted property has a status update. Open My Submissions for details.',
      'submission',new.id);
  end if;
  return new;
end; $$;
drop trigger if exists ds_v2_submission_notify_broker on public.ds_v2_property_submissions;
create trigger ds_v2_submission_notify_broker after update of status on public.ds_v2_property_submissions
for each row execute function public.ds_v2_notify_submission_broker();

-- Enable Supabase Realtime for live bell updates.
do $$ begin
  alter publication supabase_realtime add table public.ds_v2_notifications;
exception when duplicate_object then null;
when undefined_object then null;
end $$;
