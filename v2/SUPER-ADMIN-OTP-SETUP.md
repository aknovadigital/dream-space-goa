# Dream Space Goa — initial super-admin OTP setup

This setup is restricted to these two email addresses:
- kartikgarg9465@gmail.com
- brarbaljinder096@gmail.com

It does not delete existing Auth users, CRM rows, storage objects, or change the live website. It is staged on the security branch and is not live until the code is merged, deployed, and the SQL migration is applied.

## Before starting

1. Confirm both email inboxes are accessible.
2. In Supabase Dashboard → Authentication → Providers → Email, ensure email sign-in and OTP are enabled.
3. In Authentication → Email Templates, configure the **Magic Link** template to show the numeric OTP token using `{{ .Token }}`. Do not use a confirmation URL-only template for this flow. Save the template.
4. Check Authentication → URL Configuration and ensure the production site URL and redirect URLs include:
   - `https://aknovadigital.github.io/dream-space-goa/*`
   - `https://dreamspaceestate.in/*` (if the custom domain is active)

## Deploy the bootstrap Edge Function

Deploy `supabase/functions/ds-v2-admin-bootstrap/index.ts` as the function name `ds-v2-admin-bootstrap`. Keep JWT verification enabled. Ensure the project has its standard `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` Edge Function secrets. The service-role key must remain server-side and must never be placed in browser files or shared in chat.

## Initial admin setup

After the branch is merged and the function deployed, visit:

`https://aknovadigital.github.io/dream-space-goa/admin-setup.html`

For each of the two approved addresses, one at a time:
1. Enter the administrator's full name and approved email address.
2. Request the email code.
3. Enter the numeric OTP and choose a password privately.
4. The function verifies the authenticated email against the hard-coded allowlist and creates the `super_admin` profile.

Do not manually insert profile rows or create these users through the public signup page. The setup function creates an unconfirmed Auth user with a random server-generated password, sends the OTP, and only creates the profile after the verified user sets their own password.

## Apply the database allowlist

After both accounts are set up, run `v2/super-admin-allowlist-migration.sql` in Supabase SQL Editor. It enforces the two-email allowlist and verified email requirement for any future super-admin role assignment.

Then run `v2/bootstrap-super-admin-profiles.sql` only if needed to reconcile the two profiles. It checks that both allowlisted Auth users exist and are verified, and refuses to proceed if an old non-allowlisted super-admin profile exists. It does not delete or demote old accounts.

## Important

- The setup page is not a substitute for deploying the Edge Function and applying the SQL migration.
- The old accounts `paaji@gmail.com`, `akash@gmail.com`, and `kartik@gmail.com` are not deleted or modified.
- No sample data is deleted.
- Do not proceed to data cleanup until both administrators can sign in and the role restrictions have been tested.
- Supabase's default email service may impose low sending limits. If OTP delivery is unreliable, configure a custom SMTP provider in Supabase before repeated retries.
