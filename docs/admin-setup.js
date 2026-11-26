(() => {
  const cfg = window.DS_CONFIG || {};
  const $ = (s) => document.querySelector(s);
  const allowed = new Set(["kartikgarg9465@gmail.com", "brarbaljinder096@gmail.com"]);
  const message = (text) => { $("#message").textContent = text; };
  if (!window.supabase || !cfg.supabaseUrl || !cfg.supabaseAnonKey) {
    message("Supabase configuration is unavailable. Please contact the site administrator."); return;
  }
  const db = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);
  let setupName = "", setupEmail = "";
  async function call(action, extra = {}) {
    const { data, error } = await db.functions.invoke("ds-v2-admin-bootstrap", { body: { action, ...extra } });
    if (error) throw new Error(data?.error || error.message || "Request failed.");
    if (data?.error) throw new Error(data.error);
    return data;
  }
  $("#startForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    setupName = String(form.get("full_name") || "").trim();
    setupEmail = String(form.get("email") || "").trim().toLowerCase();
    if (!allowed.has(setupEmail)) return message("This email is not authorised for administrator setup.");
    $("#sendCode").disabled = true; message("Sending verification code…");
    try {
      await call("start", { email: setupEmail, full_name: setupName });
      $("#start").classList.add("hidden"); $("#verify").classList.remove("hidden");
      message("Verification code sent. Check your inbox and spam folder.");
    } catch (error) { message(error.message); $("#sendCode").disabled = false; }
  });
  $("#verifyForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const token = String(form.get("token") || "").trim();
    const password = String(form.get("password") || "");
    const confirm = String(form.get("confirm") || "");
    if (password.length < 10) return message("Use a password with at least 10 characters.");
    if (password !== confirm) return message("The passwords do not match.");
    $("#finish").disabled = true; message("Verifying code and securing your account…");
    try {
      const { data, error } = await db.auth.verifyOtp({ email: setupEmail, token, type: "email" });
      if (error || !data.user) throw error || new Error("Email verification failed.");
      const { error: passwordError } = await db.auth.updateUser({ password });
      if (passwordError) throw passwordError;
      await call("finish", { full_name: setupName });
      message("Administrator setup complete. Redirecting to login…");
      window.location.replace("admin.html");
    } catch (error) { message(error.message || "Could not complete setup. Contact the project owner."); $("#finish").disabled = false; }
  });
})();
