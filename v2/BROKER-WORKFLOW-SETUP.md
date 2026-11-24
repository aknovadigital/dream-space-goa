# Dream Space broker workflow activation

The portal code is in GitHub. The broker-account and moderated-submission features require one database migration and one Supabase Edge Function deployment before they can be used.

## 1. Apply the database migration

1. Open the Supabase project: `kctgrsqxkflbqihctmor`.
2. Open **SQL Editor** and create a new query.
3. Open `v2/broker-workflow-migration.sql` in this repository.
4. Copy the entire file into SQL Editor and run it.
5. Confirm it completes without errors.

This adds the broker property submission queue, source-broker tracking, profile self-edit rules, broker media permissions, and row-level security. It does not delete existing CRM records.

## 2. Deploy the secure broker-account function

The browser must never receive the Supabase service-role key. Broker creation, profile administration and password resets are handled by the Edge Function at `supabase/functions/ds-v2-admin-users/index.ts`.

Using Supabase CLI:

```bash
supabase login
supabase link --project-ref kctgrsqxkflbqihctmor
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
supabase functions deploy ds-v2-admin-users
```

Get the service-role key from **Supabase Dashboard → Project Settings → API Keys**. Add it only as a Supabase secret. Never paste it into GitHub, website JavaScript, or a chat.

The function verifies the signed-in user's active `super_admin` profile before performing account actions.

## 3. Check admin access

The person managing broker accounts must have an active row in `ds_v2_profiles` with role `super_admin`. Team members can continue using the regular CRM but do not see broker account controls.

## 4. Test the workflow

1. Sign in to `/admin.html`.
2. Open **Manage brokers** and create a test broker with a temporary password.
3. Sign in to `/broker.html` in a private/incognito browser window.
4. Submit a test property with photos.
5. Return to admin and open **Broker submissions**.
6. Request changes and verify the broker sees the comment and can resubmit.
7. Approve a test submission with each visibility option and confirm the listing appears only in the permitted area.

## Notes

- New broker passwords must be at least 8 characters.
- Deactivating a broker blocks access because the portal checks the profile's active flag.
- Pending submissions are not public listings and do not enter the broker inventory.
- Approval creates a property record and records the original submitting broker in `source_broker_id`.
- Public approval copies media into the public media bucket; broker/private approvals keep media in the private bucket.
- Existing properties, leads, follow-ups, deals, and Supabase Auth users are preserved.
