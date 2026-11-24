import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) return json({ error: "Server configuration is incomplete." }, 500);

  const authHeader = req.headers.get("Authorization") || "";
  const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
  const { data: authData, error: authError } = await caller.auth.getUser();
  if (authError || !authData.user) return json({ error: "Sign in required." }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await admin
    .from("ds_v2_profiles").select("role,active").eq("id", authData.user.id).maybeSingle();
  if (profileError || !profile || !profile.active || profile.role !== "super_admin") {
    return json({ error: "Only an active super admin can manage broker accounts." }, 403);
  }

  try {
    const body = await req.json();
    const action = String(body.action || "");
    if (action === "create") {
      const email = String(body.email || "").trim().toLowerCase();
      const password = String(body.password || "");
      const full_name = String(body.full_name || "").trim();
      const phone = String(body.phone || "").trim();
      if (!email || !full_name || password.length < 8) return json({ error: "Name, valid email and a password of at least 8 characters are required." }, 400);
      const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name } });
      if (error) return json({ error: error.message }, 400);
      const { error: insertError } = await admin.from("ds_v2_profiles").insert({
        id: data.user.id, full_name, email, phone, role: "broker", active: true, permissions: {}
      });
      if (insertError) {
        await admin.auth.admin.deleteUser(data.user.id);
        return json({ error: insertError.message }, 400);
      }
      return json({ broker: { id: data.user.id, full_name, email, phone, active: true } }, 201);
    }

    const id = String(body.id || "");
    if (!id) return json({ error: "Broker ID is required." }, 400);
    const { data: target, error: targetError } = await admin
      .from("ds_v2_profiles").select("id,role").eq("id", id).maybeSingle();
    if (targetError || !target || target.role !== "broker") return json({ error: "Broker account not found." }, 404);

    if (action === "update") {
      const full_name = String(body.full_name || "").trim();
      const phone = String(body.phone || "").trim();
      const email = String(body.email || "").trim().toLowerCase();
      if (!full_name || !email) return json({ error: "Name and email are required." }, 400);
      const { error: authUpdateError } = await admin.auth.admin.updateUserById(id, { email, email_confirm: true, user_metadata: { full_name } });
      if (authUpdateError) return json({ error: authUpdateError.message }, 400);
      const { error } = await admin.from("ds_v2_profiles").update({ full_name, email, phone }).eq("id", id);
      if (error) return json({ error: error.message }, 400);
      return json({ success: true });
    }
    if (action === "set_active") {
      const active = Boolean(body.active);
      const { error } = await admin.from("ds_v2_profiles").update({ active }).eq("id", id);
      if (error) return json({ error: error.message }, 400);
      return json({ success: true, active });
    }
    if (action === "reset_password") {
      const password = String(body.password || "");
      if (password.length < 8) return json({ error: "Password must contain at least 8 characters." }, 400);
      const { error } = await admin.auth.admin.updateUserById(id, { password });
      if (error) return json({ error: error.message }, 400);
      return json({ success: true });
    }
    return json({ error: "Unknown action." }, 400);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unexpected server error." }, 500);
  }
});
