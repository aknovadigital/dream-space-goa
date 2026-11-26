import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
async function hashIp(ip: string) {
  const bytes = new TextEncoder().encode(ip || "unknown");
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map(x => x.toString(16).padStart(2, "0")).join("");
}
const emailOk = (s: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s) && s.length <= 254;
const phoneOk = (s: string) => /^[+0-9() .-]{8,20}$/.test(s);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);
  const url = Deno.env.get("SUPABASE_URL"), anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return json({ error: "Server configuration is incomplete." }, 500);
  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const authHeader = req.headers.get("Authorization") || "";
  const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false, autoRefreshToken: false } });

  try {
    const body = await req.json(), action = String(body.action || "");

    if (action === "apply") {
      const full_name = String(body.full_name || "").trim();
      const area = String(body.area_of_operation || "").trim();
      const email = String(body.email || "").trim().toLowerCase();
      const phone = String(body.phone || "").trim();
      if (full_name.length < 2 || full_name.length > 100 || area.length < 2 || area.length > 160 || !emailOk(email) || !phoneOk(phone)) {
        return json({ error: "Please enter a valid name, operating area, email and mobile number." }, 400);
      }
      const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
      const forwarded = req.headers.get("cf-connecting-ip") || req.headers.get("x-real-ip") || req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
      const ipHash = await hashIp(forwarded);
      const { count: contactCount } = await admin.from("ds_v2_broker_application_rate")
        .select("id", { count: "exact", head: true }).gte("created_at", since)
        .or("email.eq."+email+",phone.eq."+phone);
      const { count: ipCount } = await admin.from("ds_v2_broker_application_rate")
        .select("id", { count: "exact", head: true }).eq("ip_hash", ipHash).gte("created_at", since);
      if ((contactCount || 0) >= 3 || (ipCount || 0) >= 5) return json({ error: "Too many applications from these contact details or network. Please try again later." }, 429);
      const { data: existingUser } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
      if ((existingUser?.users || []).some(u => u.email?.toLowerCase() === email)) {
        return json({ error: "An account already exists for this email. Please contact Dream Space." }, 409);
      }
      const { data: prior } = await admin.from("ds_v2_broker_applications")
        .select("id,status").eq("email", email).order("created_at", { ascending: false }).limit(1).maybeSingle();
      if (prior?.status === "pending") return json({ error: "An application for this email is already under review." }, 409);
      const { error: insertError } = await admin.from("ds_v2_broker_applications").insert({
        full_name, area_of_operation: area, email, phone, status: "pending",
      });
      if (insertError) return json({ error: "We could not submit the application. Please contact Dream Space." }, 400);
      await admin.from("ds_v2_broker_application_rate").insert({ email, phone, ip_hash: ipHash });
      await admin.from("ds_v2_broker_application_rate").delete().lt("created_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());
      return json({ success: true, message: "Your broker application has been submitted for review." }, 201);
    }

    const { data: authData, error: authError } = await caller.auth.getUser();
    if (authError || !authData.user) return json({ error: "Sign in required." }, 401);
    const { data: profile } = await admin.from("ds_v2_profiles").select("role,active")
      .eq("id", authData.user.id).maybeSingle();
    if (!profile?.active || profile.role !== "super_admin") return json({ error: "Only an active super admin can perform this action." }, 403);

    if (action === "reset_legacy_data") {
      // SAFETY LOCK: the previous implementation deleted every row in several tables and every object in both media buckets.
      // The intended cleanup is limited to specifically identified legacy sample records. No reliable sample IDs or
      // ownership markers have been verified yet, so destructive reset remains disabled until an explicit reviewed
      // allowlist and a non-destructive preview are implemented.
      return json({ error: "Legacy reset is temporarily disabled. No database rows, Auth users, or storage objects were changed. Identify and review the exact legacy record IDs and storage paths before enabling cleanup." }, 423);

      /* DISABLED LEGACY IMPLEMENTATION — retained temporarily for review only; unreachable due to the safety lock.
      const confirmation = String(body.confirmation || "");
      if (confirmation !== "DELETE OLD DATA") return json({ error: "Type DELETE OLD DATA to confirm this reset." }, 400);
      const { data: admins, error: adminsError } = await admin.from("ds_v2_profiles")
        .select("id,email,role,active").eq("role","super_admin").eq("active",true);
      if (adminsError || !admins || admins.length !== 2 ||
          admins.some(x => !["kartikgarg946@gmail.com","brarbaljinder096@gmail.com"].includes(String(x.email||"").toLowerCase()))) {
        return json({ error: "Reset blocked. Both approved super-admin profiles must exist and be active first." }, 409);
      }
      const allAuthUsers = [];
      for (let page = 1; page <= 20; page++) {
        const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
        if (error || !data) return json({ error: "Could not verify all Auth accounts; no data was deleted." }, 500);
        allAuthUsers.push(...data.users);
        if (data.users.length < 1000) break;
        if (page === 20) return json({ error: "More than 20,000 Auth users found. Cleanup was stopped for manual review." }, 409);
      }
      const keepIds = new Set(admins.map(x => x.id));
      const keepEmails = new Set(["kartikgarg946@gmail.com","brarbaljinder096@gmail.com"]);
      const missing = [...keepEmails].filter(email => !allAuthUsers.some(u => u.id && u.email?.toLowerCase() === email && keepIds.has(u.id)));
      if (missing.length) return json({ error: "Both approved administrator Auth users must exist before cleanup." }, 409);

      const deletedCounts: Record<string, number> = {};
      const clearTable = async (table: string) => {
        const keyColumn = table === "ds_v2_property_brokers" ? "property_id" : "id";
        const { count, error } = await admin.from(table).delete({ count: "exact" }).not(keyColumn, "is", null);
        if (error && !/does not exist|schema cache/i.test(error.message)) throw new Error("Could not clear "+table+": "+error.message);
        deletedCounts[table] = count || 0;
      };
      try {
        // Remove dependent records first. The profile and Auth accounts are retained until data is cleared.
        for (const table of [
          "ds_v2_client_shares","ds_v2_property_brokers","ds_v2_followups",
          "ds_v2_deals","ds_v2_property_submissions","ds_v2_leads",
          "ds_v2_properties","ds_v2_broker_applications","ds_v2_broker_application_rate",
          "ds_v2_site_interactions"
        ]) await clearTable(table);

        // Delete all files in the two existing V2 buckets, preserving the buckets and policies.
        const storageRemoved: Record<string, number> = {};
        for (const bucket of ["ds-v2-property-media","ds-v2-public-media"]) {
          const paths: string[] = [], walk = async (prefix: string) => {
            let offset = 0;
            while (true) {
              const { data, error } = await admin.storage.from(bucket).list(prefix, { limit: 1000, offset });
              if (error) throw new Error("Could not list storage bucket "+bucket+": "+error.message);
              if (!data?.length) break;
              for (const item of data) {
                const full = prefix ? prefix+"/"+item.name : item.name;
                if (item.id === null) await walk(full);
                else paths.push(full);
              }
              if (data.length < 1000) break;
              offset += data.length;
            }
          };
          await walk("");
          for (let i=0;i<paths.length;i+=100) {
            const { error } = await admin.storage.from(bucket).remove(paths.slice(i,i+100));
            if (error) throw new Error("Could not clear storage bucket "+bucket+": "+error.message);
          }
          storageRemoved[bucket] = paths.length;
        }

        const { error: profileDeleteError, count: profileCount } = await admin.from("ds_v2_profiles")
          .delete({ count: "exact" }).not("id","in","("+[...keepIds].join(",")+")");
        if (profileDeleteError) throw new Error("Could not remove old profiles: "+profileDeleteError.message);
        deletedCounts["ds_v2_profiles"] = profileCount || 0;

        let authDeleted = 0;
        for (const u of allAuthUsers) {
          if (!u.id || keepIds.has(u.id) || keepEmails.has((u.email||"").toLowerCase())) continue;
          const { error } = await admin.auth.admin.deleteUser(u.id);
          if (error) throw new Error("Could not delete an old login account: "+error.message);
          authDeleted++;
        }
        return json({ success: true, deletedCounts, storageRemoved, authUsersDeleted: authDeleted,
          preservedAdmins: [...keepEmails], message: "Old V2 records, non-admin logins and V2 media have been removed. Website schema, buckets and the two administrators were preserved." });
      } catch (err) {
        return json({ error: err instanceof Error ? err.message : "Cleanup stopped. Review Supabase before retrying.", partial: deletedCounts }, 500);
      }
      */
    }

    if (action === "list_applications") {
      const { data, error } = await admin.from("ds_v2_broker_applications").select("*").order("created_at", { ascending: false });
      if (error) return json({ error: "Could not load applications." }, 500);
      return json({ applications: data || [] });
    }

    if (action === "review_application") {
      const id = String(body.id || ""), decision = String(body.decision || "");
      const note = String(body.admin_note || "").trim().slice(0, 1000);
      if (!id || !["approved", "rejected"].includes(decision)) return json({ error: "Invalid application decision." }, 400);
      const { data: app } = await admin.from("ds_v2_broker_applications").select("*").eq("id", id).maybeSingle();
      if (!app || app.status !== "pending") return json({ error: "Pending application not found." }, 404);
      if (decision === "rejected") {
        const { error } = await admin.from("ds_v2_broker_applications").update({
          status: "rejected", admin_note: note || null, reviewed_by: authData.user.id,
          reviewed_at: new Date().toISOString(),
        }).eq("id", id);
        if (error) return json({ error: "Could not reject application." }, 500);
        return json({ success: true, status: "rejected" });
      }
      const password = String(body.password || "");
      if (password.length < 10 || password.length > 128) return json({ error: "Admin must assign a password of at least 10 characters." }, 400);
      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email: app.email, password, email_confirm: true,
        user_metadata: { full_name: app.full_name, ds_broker_approved: true },
      });
      if (createError || !created.user) return json({ error: "Could not create broker login. The email may already have an Auth account." }, 409);
      const { error: profileError } = await admin.from("ds_v2_profiles").insert({
        id: created.user.id, full_name: app.full_name, email: app.email, phone: app.phone,
        area_of_operation: app.area_of_operation, role: "broker", active: true, permissions: {},
      });
      if (profileError) {
        await admin.auth.admin.deleteUser(created.user.id);
        return json({ error: "Could not create broker profile." }, 500);
      }
      const { error: appError } = await admin.from("ds_v2_broker_applications").update({
        status: "approved", admin_note: note || null, reviewed_by: authData.user.id,
        reviewed_at: new Date().toISOString(), profile_id: created.user.id,
      }).eq("id", id);
      if (appError) return json({ error: "Broker account created, but application status needs administrator review." }, 500);
      return json({ success: true, status: "approved" });
    }

    if (action === "create_broker") {
      const full_name = String(body.full_name || "").trim(), email = String(body.email || "").trim().toLowerCase();
      const phone = String(body.phone || "").trim(), area = String(body.area_of_operation || "").trim();
      if (full_name.length < 2 || !emailOk(email) || !phoneOk(phone) || area.length < 2) return json({ error: "Name, valid email, mobile and operating area are required." }, 400);
      const password = String(body.password || "");
      if (password.length < 10 || password.length > 128) return json({ error: "Assign a password of at least 10 characters." }, 400);
      const { data: created, error } = await admin.auth.admin.createUser({
        email, password, email_confirm: true,
        user_metadata: { full_name, ds_broker_admin_created: true },
      });
      if (error || !created.user) return json({ error: "Could not create account. This email may already be registered." }, 409);
      const { error: pError } = await admin.from("ds_v2_profiles").insert({
        id: created.user.id, full_name, email, phone, area_of_operation: area,
        role: "broker", active: true, permissions: {},
      });
      if (pError) { await admin.auth.admin.deleteUser(created.user.id); return json({ error: "Could not create broker profile." }, 500); }
      return json({ success: true });
    }

    if (action === "update_broker") {
      const id = String(body.id || ""), full_name = String(body.full_name || "").trim();
      const phone = String(body.phone || "").trim(), area = String(body.area_of_operation || "").trim();
      if (!id || full_name.length < 2 || !phoneOk(phone) || area.length < 2) return json({ error: "Name, valid mobile and operating area are required." }, 400);
      const { error } = await admin.from("ds_v2_profiles").update({
        full_name, phone, area_of_operation: area,
      }).eq("id", id).eq("role", "broker");
      if (error) return json({ error: "Could not update broker details." }, 400);
      return json({ success: true });
    }

    if (action === "set_active") {
      const id = String(body.id || ""), active = Boolean(body.active);
      const { error } = await admin.from("ds_v2_profiles").update({ active }).eq("id", id).eq("role", "broker");
      if (error) return json({ error: "Could not update broker status." }, 500);
      return json({ success: true, active });
    }
    return json({ error: "Unknown action." }, 400);
  } catch (_error) {
    return json({ error: "Unexpected server error." }, 500);
  }
});
