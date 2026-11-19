# Dream Space Goa V2

A clean V2 implementation isolated from the existing website and database objects.

## Stack
- Static frontend hosted on GitHub Pages
- Supabase Auth, Postgres and Storage
- Vanilla HTML/CSS/JavaScript (no build step)

## Setup
1. In the existing Supabase project, open SQL Editor.
2. Review and run `schema.sql`. It creates only `ds_v2_*` objects and does not drop or alter the old schema.
3. Create a private Storage bucket named `ds-v2-property-media`.
4. Copy `config.example.js` to `config.js` and add the project's Supabase URL and anon/publishable key. Do not put a service-role key in browser code.
5. Create an Auth user for the first administrator. Then insert that user's UUID into `public.ds_v2_profiles` with role `super_admin` using the SQL Editor.
6. Open `index.html` through a local static server or publish the branch using a separate GitHub Pages workflow/site.

## Current scope
This is the clean V2 foundation and UI shell. Database schema and RLS are the security boundary. Broker/client portal flows, storage upload UI, reminder delivery and full CRUD screens are staged for subsequent implementation and testing.

## Important
Do not run old SQL files for V2. Do not expose Supabase service-role credentials. Configure Auth redirect URLs and email templates in Supabase before enabling production login.
