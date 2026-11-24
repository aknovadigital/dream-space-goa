<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dream Space | Admin Workspace</title><link rel="stylesheet" href="admin.css"></head>
<body><div id="loginView" class="login-wrap"><form id="adminLogin" class="login-card"><p class="eyebrow">DREAM SPACE GOA · PRIVATE WORKSPACE</p><h1>Welcome back.</h1><p class="muted">Sign in to manage your properties and client relationships.</p><label>Email<input name="email" type="email" required autocomplete="username"></label><label>Password<input name="password" type="password" required autocomplete="current-password"></label><button class="primary">Sign in</button><p id="loginError" class="notice"></p></form></div>
<div id="appView" class="app hidden"><aside class="sidebar"><a class="brand" href="index.html"><img src="assets/dream-space-logo.svg" alt="Dream Space"><small>ADMIN WORKSPACE</small></a><div class="side-label">WORKSPACE</div><button class="nav active" data-view="overview">Overview</button><button class="nav" data-view="properties">Properties</button><button class="nav" data-view="leads">Leads & clients</button><button class="nav" data-view="followups">Follow-ups</button><button class="nav" data-view="deals">Closed deals</button><button class="nav extra-nav" data-extra-view="brokers">Manage brokers</button><button class="nav extra-nav" data-extra-view="submissions">Submissions</button><div class="side-bottom"><span id="signedInAs"></span><button id="logoutBtn" class="quiet">Sign out</button></div></aside>
<main class="main"><header class="topbar"><div><p class="eyebrow">DREAM SPACE GOA</p><h1 id="pageTitle">Business overview</h1></div><span class="live">V2 WORKSPACE</span></header>
<section id="overviewView" class="view"><div class="stats" id="stats"></div><div class="panel"><div class="panel-head"><h2>Today's follow-ups</h2><button class="small" data-goto="followups">View all</button></div><div id="todayList" class="table-wrap"></div></div><div class="panel"><div class="panel-head"><h2>Recent enquiries</h2><button class="small" data-goto="leads">View all</button></div><div id="recentLeads" class="table-wrap"></div></div></section>
<section id="propertiesView" class="view hidden"><div class="toolbar"><p class="muted">Manage public, broker, exclusive and internal inventory.</p><button class="primary" id="addProperty">+ Add property</button></div><div class="filters"><input id="propertySearch" placeholder="Search title or location"><select id="categoryFilter"><option value="">All inventory</option><option value="public">Public</option><option value="broker">Broker</option><option value="exclusive">Exclusive client</option><option value="private">Private / internal</option></select></div><div class="panel table-wrap" id="propertiesTable"></div></section>
<section id="leadsView" class="view hidden"><div class="toolbar"><p class="muted">Manage enquiries, requirements and lead progress.</p><button class="primary" id="addLead">+ Add lead</button></div><div class="panel table-wrap" id="leadsTable"></div></section>
<section id="followupsView" class="view hidden"><div class="toolbar"><p class="muted">Calls, meetings and site visits that need attention.</p><button class="primary" id="addFollowup">+ Schedule follow-up</button></div><div class="panel table-wrap" id="followupsTable"></div></section>
<section id="dealsView" class="view hidden"><div class="toolbar"><p class="muted">Completed transactions and brokerage records.</p><button class="primary" id="addDeal">+ Record deal</button></div><div class="panel table-wrap" id="dealsTable"></div></section>
<section id="brokersExtraView" class="view hidden"><div class="toolbar"><p class="muted">Create and manage broker accounts.</p><button class="primary" id="newBroker">+ Add broker</button></div><div class="panel table-wrap" id="brokersTable"></div></section>
<section id="submissionsExtraView" class="view hidden"><div class="toolbar"><p class="muted">Review broker property submissions before publication.</p><button class="small" id="refreshSubmissions">Refresh</button></div><div id="submissionsList" class="submission-list"></div></section>
</main></div>
<dialog id="editor"><form id="editorForm"><div class="modal-head"><h2 id="editorTitle">Add record</h2><button type="button" class="quiet" id="closeEditor">✕</button></div><div id="editorFields" class="fields"></div><section id="mediaManager" class="media-manager hidden"><h3>Property photos & videos</h3><p class="muted">Upload images or videos for this property. Files are stored in the private Dream Space media bucket.</p><input id="propertyMediaFiles" type="file" accept="image/*,video/mp4,video/webm,video/quicktime" multiple><div id="mediaList" class="media-list"></div></section><p id="editorError" class="notice"></p><div class="modal-actions"><button type="button" class="quiet" id="cancelEditor">Cancel</button><button class="primary">Save record</button></div></form></dialog>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script><script src="config.js"></script><script src="admin.js"></script><script src="admin-extra.js"></script></body></html>
-- Restrict broker updates to their own resubmission data and media.
create or replace function public.ds_v2_guard_broker_submission_update()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() = old.broker_id and not public.ds_v2_is_staff() then
    if old.status not in ('pending','changes_requested')
      or new.broker_id is distinct from old.broker_id
      or new.status <> 'pending'
      or new.admin_comment is distinct from old.admin_comment
      or new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at
      or new.approved_property_id is distinct from old.approved_property_id
      or new.created_at is distinct from old.created_at then
      raise exception 'Only resubmission of your own pending or changes-requested property is allowed.';
    end if;
    if old.status = 'pending' and (to_jsonb(new) - 'media' - 'updated_at') is distinct from (to_jsonb(old) - 'media' - 'updated_at') then
      raise exception 'A pending submission cannot be edited unless the admin requests changes.';
    end if;
  end if;
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists ds_v2_submission_update_guard on public.ds_v2_property_submissions;
create trigger ds_v2_submission_update_guard before update on public.ds_v2_property_submissions
for each row execute function public.ds_v2_guard_broker_submission_update();
