// Retired: super-admin accounts are created manually in Supabase Dashboard.
// No OTP, email verification, or public administrator setup endpoint is used.
Deno.serve((_req) => new Response(JSON.stringify({
  error: "This administrator bootstrap endpoint has been retired. Create approved administrator users in Supabase Dashboard and follow v2/SUPER-ADMIN-MANUAL-SETUP.md."
}), {
  status: 410,
  headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
}));
