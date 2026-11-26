# Dream Space Goa — deployment checklist

All changes are staged on `security/broker-approval-auth-reset`. They are not live until reviewed, merged, migrations applied, and Edge Functions deployed.

## Agreed authentication behaviour

- No OTP, email verification workflow, SMTP, email notifications, SMS, or messaging provider is used.
- The two super-admin Auth users are created manually by the project owner in Supabase Dashboard.
- Super-admin access is restricted to:
  - `kartikgarg9465@gmail.com`
  - `brarbaljinder096@gmail.com`
- Public broker applications create a pending application only; they do not create Auth users.
- A super admin approves or rejects applications manually. On approval, the admin assigns the initial password and the broker account is created immediately.
- Admin-created brokers also receive an admin-assigned initial password.
- Brokers sign in with email and password.
- Brokers can change their password only by entering the old password, new password, and confirmation. The old password is checked by signing in again before the password is updated.
- No forgot-password, broker reset-password, or admin reset-password control exists.
- Passwords are passed to Supabase Auth over HTTPS and are not stored in application tables.
- Broker inventory is limited to public listings and exclusive listings assigned to that broker. Private listings and other brokers' exclusive listings remain inaccessible.
- Brokers cannot edit or delete existing property listings.

## Before deployment

1. Confirm access to the Supabase project and repository.
2. In Supabase Dashboard → Authentication → Users, create these two users manually and assign strong passwords:
   - `kartikgarg9465@gmail.com`
   - `brarbaljinder096@gmail.com`
3. Do not use public sign-up or any setup page for administrator creation.
4. Disable unrestricted public Auth signups if enabled. Broker applications are reviewed by admins and only create Auth users after approval.
5. No SMTP, email templates, OTP delivery, recovery templates, or email redirect setup is needed for this workflow.

## Apply SQL migrations

Run these in Supabase SQL Editor in this order, after confirming the existing V2 schema and broker visibility migration are already present:

1. `v2/broker-applications-security-migration.sql`
2. `v2/broker-application-rate-limit.sql`
3. `v2/broker-assigned-inventory-only.sql`
4. `v2/super-admin-allowlist-migration.sql`
5. `v2/bootstrap-super-admin-profiles.sql`
6. `v2/public-property-safe-view.sql`

The migrations add the broker application workflow, restrict broker access, add a public-safe property view, and link the two manually created Auth users to super-admin profiles. Review the SQL output after each step. Do not run the old-data reset as part of migration deployment.

## Deploy Edge Functions

Deploy from the repository using Supabase CLI with JWT verification enabled for authenticated admin actions:

- `ds-v2-broker-workflow`
- `ds-v2-admin-users` (retired endpoint; returns HTTP 410 and blocks legacy password-management actions)

The old `ds-v2-admin-bootstrap` function is no longer used. Delete/disable that deployed function in Supabase after confirming the new manual admin accounts work.

Ensure server-side Edge Function secrets are configured: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`. Never place the service-role key in browser code, repository files, or chat.

## Test before launch

- Both approved admins can sign in and have active `super_admin` profiles.
- A non-allowlisted user cannot become a super admin.
- Public broker application creates only a pending application row and no Auth user.
- Admin can approve/reject an application; approval requires admin-assigned initial password and creates an active broker.
- Admin can directly create a broker with assigned initial password.
- Brokers can sign in using email and password.
- Correct old password + matching new password changes broker password; incorrect old password fails.
- There is no forgot-password or reset-password UI or flow.
- Rejected applicants cannot sign in.
- Broker sees public listings and only exclusive listings assigned to that broker.
- Broker cannot see private inventory or another broker's exclusive listings/media.
- Broker cannot edit/delete existing inventory.
- Public pages read the safe property view; anonymous direct reads from the base properties table are denied.
- Existing public pages, enquiry forms, admin CRM, and property submission workflow continue to work.

## Old-data reset — last step only

The admin portal includes a guarded **Reset old website data** action. It is destructive and must not be used until both approved admins can sign in and all new workflows have been tested.

The reset is intended to clear old V2 properties, leads, follow-ups, deals, client shares, broker-property assignments, broker submissions, broker applications, rate-limit rows, V2 site interactions, old V2 profiles, old Auth users, and files in the two existing V2 media buckets. It preserves the website files, database schema, policies/functions, storage buckets, Supabase project settings, and the two approved super-admin accounts.

Before running it, take a Supabase backup/export and verify the exact records and storage objects to be removed. Then use the admin portal's two-step confirmation. If it reports a partial failure, stop and inspect Supabase before retrying. This reset cannot be undone.
