# Dream Space Goa — security deployment checklist

All changes are staged on `security/broker-approval-auth-reset`. They are not live until reviewed, merged, migrations applied and Edge Functions deployed.

## Included work

- Allowlist for exactly the two approved super-admin email addresses.
- Private OTP-based super-admin bootstrap and password setup.
- Public broker application form and server-side application endpoint.
- Admin pending-application queue with approve/reject actions.
- Approved and admin-created broker accounts receive email OTP and set their own password.
- Broker activation requires verified email; new broker profiles remain inactive until activation.
- Broker password recovery uses email OTP, not an admin-entered password.
- Broker inventory access: public listings plus exclusive listings explicitly assigned to that broker; no shared broker-category inventory.
- Public-safe property view excludes owner contact details, commission and internal notes from anonymous access.
- Retired the old plaintext-password broker admin endpoint.

## Before deployment

1. Confirm both approved admin inboxes can receive email.
2. Supabase Dashboard → Authentication → Providers → Email: enable email sign-in and OTP.
3. Keep email confirmation enabled.
4. Disable unrestricted public Auth signups if your Supabase project permits it. Broker applicants are only applications until approved; they must not create Auth users directly.
5. Supabase Dashboard → Authentication → Email Templates:
   - Configure the Magic Link/OTP template to show the numeric token using `{{ .Token }}`.
   - Include instructions and the static activation page URL: `https://aknovadigital.github.io/dream-space-goa/broker-activate.html`.
   - Also mention the admin setup page: `https://aknovadigital.github.io/dream-space-goa/admin-setup.html`.
   - Configure the recovery template to show the numeric recovery token and the recovery page URL: `https://aknovadigital.github.io/dream-space-goa/broker-reset.html`.
   - Do not rely on a confirmation link-only template; users need the numeric OTP.
6. Authentication → URL Configuration: add the GitHub Pages and custom domain redirect URLs, including `https://aknovadigital.github.io/dream-space-goa/*` and `https://dreamspaceestate.in/*` if active.

## Apply SQL migrations

Run these in Supabase SQL Editor in this order, after confirming the existing V2 schema and broker workflow migration are already present:

1. `v2/broker-applications-security-migration.sql`
2. `v2/broker-application-rate-limit.sql`
3. `v2/super-admin-allowlist-migration.sql`
4. `v2/public-property-safe-view.sql`
5. After both new admin Auth users have been OTP verified and set their passwords, run `v2/bootstrap-super-admin-profiles.sql` only if the profiles need reconciliation.

The migrations are additive and do not delete sample records, Auth users, storage objects, buckets, or website files.

## Deploy Edge Functions

Deploy these functions from the repository using Supabase CLI, keeping JWT verification enabled:

- `ds-v2-admin-bootstrap`
- `ds-v2-broker-workflow`
- `ds-v2-admin-users` (the retired endpoint returns HTTP 410 and prevents old plaintext-password actions)

Ensure standard Edge Function secrets are present: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`. Never place the service-role key in browser code or GitHub.

## First administrator setup

After deployment and migration, open `https://aknovadigital.github.io/dream-space-goa/admin-setup.html` and set up each approved admin account separately. Each must receive an OTP and privately set a password. Do not create them manually in Auth first; the bootstrap function creates the pending Auth record.

## Test before launch

- Both admins can sign in with email/password and have super_admin profiles.
- A non-allowlisted account cannot become super_admin.
- A public broker application creates only a pending application row, not an Auth user.
- Admin can approve/reject; only approved applications receive OTP.
- Broker activation verifies OTP, sets password, and activates the profile.
- Rejected applicants cannot log in or access broker pages.
- Forgot password sends a recovery OTP; new password works.
- Admin-created brokers follow the same OTP activation flow.
- Broker sees public inventory and only assigned exclusive listings.
- Broker cannot see private inventory or another broker's exclusive listings.
- Broker cannot edit/delete existing inventory.
- Public pages can read the safe view; anonymous direct reads from the base properties table are denied.
- Public leads/enquiry form and all existing website pages still work.

## Remaining operational limitations

- Admin dashboard pending queue is implemented; email notifications to admins are not configured. Add a transactional email provider before relying on email alerts.
- Supabase default email sending may be rate-limited; use custom SMTP for reliable OTP delivery.
- This work does not itself execute SQL, deploy Edge Functions, or change the live Supabase project.

## Data cleanup — last step only

After all tests pass and both administrators have confirmed access, prepare and review a separate cleanup script. Delete only identified V2 test rows, non-admin test Auth users and test media objects. Preserve the schema, website, two super-admin accounts, buckets, policies and any genuine records. No cleanup is included in this deployment.
