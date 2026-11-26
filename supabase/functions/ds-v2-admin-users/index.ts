// Deprecated: broker account administration now uses ds-v2-broker-workflow.
// This endpoint intentionally refuses all requests so plaintext-password
// creation/reset is not available after this version is deployed.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
Deno.serve((req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  return new Response(JSON.stringify({
    error: "This broker management endpoint has been retired. Deploy and use ds-v2-broker-workflow."
  }), { status: 410, headers: { ...cors, "Content-Type": "application/json" } });
});
