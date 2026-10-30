# Dream Space Goa CRM setup

The website code is connected to Supabase using the project URL and publishable key. Complete the steps below before using the admin panel.

## 1. Create database tables and security policies

1. Open the Supabase project.
2. Open **SQL Editor**.
3. Open the repository file `supabase-setup.sql`.
4. Copy the complete SQL into a new SQL query and run it.

This creates `profiles`, `properties`, and `inquiries`, enables Row Level Security, and creates the public `property-images` Storage bucket with admin-only upload/update/delete policies.

## 2. Create the owner login

1. In Supabase, open **Authentication → Users**.
2. Choose **Add user** / **Create new user**.
3. Enter the owner's email and a strong password. Confirm the user if the dashboard offers that option.
4. Copy the new user's UUID.
5. Open **SQL Editor** and run this statement, replacing both placeholders:

```sql
insert into public.profiles (id, email, role)
values ('AUTH-USER-UUID-HERE', 'OWNER-EMAIL-HERE', 'admin');
```

The profile row grants admin access. Do not make this table publicly writable.

## 3. Open the admin panel

Visit `https://aknovadigital.github.io/dream-space-goa/admin/` and sign in with the owner email and password.

## 4. Add properties

Go to **Properties → Add property**. Add the details and photos. Keep the status as Draft while preparing a listing. Change it to Published to make it appear on the public website.

Sold, rented, draft and archived listings are not displayed publicly.

## 5. Enquiries

Website enquiries are inserted into `inquiries`. The admin can update status, notes and next follow-up from the Enquiries page.

## Important security notes

- The browser uses only the Supabase publishable key. Never put a service-role or secret key in website files.
- Keep Row Level Security enabled. Do not add permissive public read policies to `inquiries` or public write policies to `properties`.
- The owner account must have a matching `profiles` row with role `admin`.
- This first version is owner-only. Do not share the owner login. Staff roles and per-user permissions can be added later.
- The website's public enquiry form stores the enquiry in Supabase and then opens WhatsApp with the same details. The visitor must still press Send in WhatsApp.
- Verify the business has permission to publish every listing and photo, and confirm availability/pricing before publishing.
- The Supabase Storage bucket is public for image viewing. Do not upload private documents or identity proofs there.
