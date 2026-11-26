# Dream Space Goa — manual super-admin setup

The project owner creates the two super-admin accounts directly in Supabase. This application does not send OTPs or verification emails.

Approved administrator addresses:
- kartikgarg9465@gmail.com
- brarbaljinder096@gmail.com

## 1. Create Auth users

In Supabase Dashboard → Authentication → Users, create one user for each approved address and assign a strong password. Do not create these users through public sign-up. No email delivery or OTP step is part of this process.

## 2. Apply the super-admin SQL

After both Auth users exist, run these repository SQL files in Supabase SQL Editor:

1. `v2/super-admin-allowlist-migration.sql`
2. `v2/bootstrap-super-admin-profiles.sql`

The bootstrap SQL links each Auth user ID to an active `super_admin` profile. It does not create Auth users, set passwords, or delete existing records.

## 3. Test access

Open the Admin Portal and sign in with each administrator's email and password. Confirm both profiles show role `super_admin` and active status.

Only these two addresses can be assigned the super-admin role by the allowlist trigger. Keep administrator passwords private and never put them in repository files or chat.

## Important

Do not run the old-data reset until both admins have successfully signed in and the broker workflow has been tested. Take a backup before any destructive cleanup.
