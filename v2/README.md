# Dream Space Goa V2

A clean V2 implementation isolated from the existing website and legacy database objects.

## Stack
- Static HTML/CSS/JavaScript frontend
- Supabase Auth, Postgres and private Storage
- No build step required

## Files
- `index.html`, `styles.css`, `app.js`: public property website and enquiry form
- `admin.html`, `admin.css`, `admin.js`: private admin workspace with overview, property inventory, leads, follow-ups and closed deals
- `schema.sql`: additive V2 database schema; all tables are prefixed `ds_v2_`
- `storage-policies.sql`: private property media bucket policies
- `config.example.js`: browser-safe configuration template

## Setup
1. In the existing Supabase project, run `schema.sql` in SQL Editor.
2. Create a private Storage bucket named `ds-v2-property-media`.
3. Run `storage-policies.sql` in SQL Editor.
4. Copy `config.example.js` to `config.js` inside this `v2` folder and add the project's Supabase URL and anon/publishable key. Never use the service-role key in browser code.
5. Create an Auth user for the first administrator in Supabase Authentication.
6. In SQL Editor, add that user's UUID to `public.ds_v2_profiles`:
   ```sql
   insert into public.ds_v2_profiles (id, full_name, email, role)
   values ('AUTH-USER-UUID', 'Admin Name', 'admin@example.com', 'super_admin');
   ```
7. Open `v2/index.html` and `v2/admin.html` through a local static server for testing, or publish the V2 folder using a separate preview deployment.

## Security notes
- V2 tables and policies are separate from legacy tables; the migration does not drop or modify legacy objects.
- Public property reads are limited to `inventory_category='public'` and available/under-offer inventory.
- Internal tables are staff-only. Broker property access is limited by broker assignment policy.
- The media bucket is private and currently staff-only. Do not make it public.
- Configure Supabase Auth site URL and redirect URLs for the final preview/production domains.

## Current implementation status
Implemented foundation: public property search/listing, public enquiry insert, password login, admin dashboard overview, property CRUD, lead CRUD, follow-up CRUD/completion, and deal CRUD.

Still to implement and test: image/video upload UI, broker assignment management screens, client private-link generation/verification, team permission editor, richer client profile workflow, reminder delivery/notifications, and end-to-end security/functional testing. The `permissions` JSON field is reserved for the future permission editor; team users currently receive the staff-level data access described in the policies.

## Important
Do not run the old SQL files for V2. Do not expose Supabase service-role credentials. Test the new version before connecting it to the live domain.
