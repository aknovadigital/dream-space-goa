import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const allowed = new Set(["kartikgarg9465@gmail.com", "brarbaljinder096@gmail.com"]);
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return json({ error: "Server configuration is incomplete." }, 500);

  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const authHeader = req.headers.get("Authorization") || "";
  const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false, autoRefreshToken: false } });

  try {
    const body = await req.json();
    const action = String(body.action || "");

    if (action === "start") {
      const email = String(body.email || "").trim().toLowerCase();
      const fullName = String(body.full_name || "").trim();
      if (!allowed.has(email)) return json({ error: "This email is not on the administrator allowlist." }, 403);
      if (!fullName || fullName.length > 100) return json({ error: "Enter your full name." }, 400);

      // Create an unconfirmed Auth user with an unshared random password.
      const randomPassword = crypto.randomUUID() + "Aa9!";
      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email, password: randomPassword, email_confirm: false,
        user_metadata: { full_name: fullName, ds_admin_bootstrap: true },
      });
      if (createError || !created.user) {
        return json({ error: "Could not start setup. This address may already have an Auth account; contact the project owner before retrying." }, 409);
      }

      const { error: otpError } = await caller.auth.signInWithOtp({ email, options: { shouldCreateUser: false } });
      if (otpError) {
        await admin.auth.admin.deleteUser(created.user.id);
        return json({ error: "Could not send the verification code. Check the Supabase email provider and OTP template, then retry." }, 502);
      }
      return json({ success: true, message: "A verification code has been sent to the approved email address." });
    }

    if (action === "finish") {
      const { data: authData, error: authError } = await caller.auth.getUser();
      const user = authData.user;
      if (authError || !user || !user.email || !allowed.has(user.email.toLowerCase()) || !user.email_confirmed_at) {
        return json({ error: "Complete email OTP verification first." }, 401);
      }
      const fullName = String(body.full_name || user.user_metadata?.full_name || "").trim();
      if (!fullName || fullName.length > 100) return json({ error: "Enter your full name." }, 400);

      const { count, error: countError } = await admin.from("ds_v2_profiles")
        .select("id", { count: "exact", head: true }).eq("role", "super_admin").neq("id", user.id);
      if (countError) return json({ error: "Could not validate administrator slots." }, 500);
      if ((count || 0) >= 2) return json({ error: "Both super-admin positions are already assigned." }, 409);

      const { error: profileError } = await admin.from("ds_v2_profiles").upsert({
        id: user.id, full_name: fullName, email: user.email.toLowerCase(),
        role: "super_admin", active: true, permissions: {},
      }, { onConflict: "id" });
      if (profileError) return json({ error: "Email verified, but profile setup failed. Contact the project owner before retrying." }, 500);
      return json({ success: true, message: "Administrator account is ready. You can now sign in with your email and password." });
    }

    return json({ error: "Unknown action." }, 400);
  } catch (_error) {
    return json({ error: "Unexpected server error." }, 500);
  }
});
