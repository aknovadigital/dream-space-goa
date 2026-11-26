(() => {
  const cfg = window.DS_CONFIG || {};
  const client = (window.supabase && cfg.supabaseUrl && cfg.supabaseAnonKey && !cfg.supabaseUrl.includes("YOUR-PROJECT"))
    ? window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey) : null;
  const $ = (s) => document.querySelector(s);
  let requestedLoginRole = null;
  $("#year").textContent = new Date().getFullYear();
  function openLogin() {
    requestedLoginRole = null;
    $("#loginTitle").textContent = "Choose your login";
    $("#loginMessage").textContent = "";
    $("#loginForm").hidden = true;
    $(".login-choices").hidden = false;
    $("#adminDialog").showModal();
  }
  function chooseLogin(role) {
    requestedLoginRole = role;
    $("#loginTitle").textContent = role === "admin" ? "Admin Login" : "Broker Login";
    $("#loginMessage").textContent = "";
    $(".login-choices").hidden = true;
    $("#loginForm").hidden = false;
  }
  $("#adminLoginChoice").addEventListener("click", () => chooseLogin("admin"));
  $("#brokerLoginChoice").addEventListener("click", () => chooseLogin("broker"));
  async function routeSignedInUser() {
    if (!client) return false;
    const { data: sessionData } = await client.auth.getSession();
    const user = sessionData?.session?.user;
    if (!user) return false;
    const { data: profile, error } = await client.from("ds_v2_profiles")
      .select("role,active").eq("id", user.id).single();
    if (error || !profile || !profile.active || !["super_admin","team_member","broker"].includes(profile.role)) {
      $("#loginMessage").textContent = "This account is not active or authorised. Please contact the administrator.";
      return false;
    }
    window.location.href = profile.role === "broker" ? "broker.html" : "admin.html";
    return true;
  }
  $("#adminOpen").addEventListener("click", async () => {
    if (!(await routeSignedInUser())) openLogin();
  });
  $("#adminOpenMobile").addEventListener("click", async () => {
    if (!(await routeSignedInUser())) openLogin("admin");
  });

  async function loadProperties() {
    const grid = $("#propertyGrid");
    if (!client) return;
    let q = client.from("ds_v2_properties").select("id,title,slug,location,property_type,listing_type,price,currency,bedrooms,bathrooms,media").eq("inventory_category","public").in("availability",["available","under_offer"]).order("created_at",{ascending:false});
    const listing = $("#filterListing").value, location = $("#filterLocation").value.trim(), type = $("#filterType").value;
    if (listing) q = q.eq("listing_type",listing);
    if (location) q = q.ilike("location", "%" + location + "%");
    if (type) q = q.eq("property_type",type);
    const {data,error} = await q;
    if (error) { grid.innerHTML = '<div class="empty">Property listings are temporarily unavailable.</div>'; return; }
    if (!data || !data.length) { grid.innerHTML = '<div class="empty">No matching properties yet. Contact our team and we will help you find the right property.</div>'; return; }
    grid.innerHTML = data.map(p => {
      const firstMedia=Array.isArray(p.media)?p.media.find(m=>m && (m.bucket==="ds-v2-public-media" || m.url)):null;
      const img=firstMedia?(firstMedia.url||client.storage.from(firstMedia.bucket).getPublicUrl(firstMedia.path).data.publicUrl):"https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=900&q=80";
      const price = p.price ? new Intl.NumberFormat("en-IN",{style:"currency",currency:p.currency || "INR",maximumFractionDigits:0}).format(p.price) : "Price on request";
      return '<a class="property-card" href="property.html?slug='+encodeURIComponent(p.slug||p.id)+'"><img loading="lazy" src="'+escapeHtml(img)+'" alt="'+escapeHtml(p.title)+'"><div class="property-info"><small>'+escapeHtml(p.listing_type.replaceAll("_"," "))+" · "+escapeHtml(p.property_type)+'</small><h3>'+escapeHtml(p.title)+'</h3><p>'+escapeHtml(p.location)+' · '+price+'</p><span class="text-link">View property details ↗</span></div></a>';
    }).join("");
  }
  function escapeHtml(v) { return String(v ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])); }
  $("#searchBtn").addEventListener("click", loadProperties);
  if (client) loadProperties();

  document.addEventListener("click", e => {
    const link=e.target.closest('a[href^="tel:"],a[href*="wa.me"]');
    if(!link||!client)return;
    const interaction_type=link.href.startsWith("tel:")?"call_click":"whatsapp_click";
    client.from("ds_v2_site_interactions").insert({interaction_type,page_path:location.pathname}).then(({error})=>{if(error)console.warn("Interaction tracking unavailable:",error.message)});
  });

  $("#enquiryForm").addEventListener("submit", async e => {
    e.preventDefault(); const f = new FormData(e.currentTarget);
    const payload = {full_name:f.get("full_name"),phone:f.get("phone"),email:f.get("email") || null,requirement_type:f.get("requirement_type"),notes:f.get("message") || null,source:"website"};
    if (!client) { $("#formMessage").textContent = "Website enquiry is not connected yet. Please contact us on WhatsApp."; return; }
    const {error} = await client.from("ds_v2_leads").insert(payload);
    $("#formMessage").textContent = error ? "We could not submit your enquiry. Please try again or contact us directly." : "Thank you. Your enquiry has been received.";
    if (!error) e.currentTarget.reset();
  });


  const brokerApplyForm = $("#brokerApplicationForm");
  if (brokerApplyForm) brokerApplyForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const f = new FormData(brokerApplyForm), msg = $("#brokerApplicationMessage"), button = brokerApplyForm.querySelector("button[type=submit],button:not([type])");
    if (!client) { msg.textContent = "Application service is temporarily unavailable. Please contact Dream Space."; return; }
    button.disabled = true; msg.textContent = "Submitting your application…";
    try {
      const { data, error } = await client.functions.invoke("ds-v2-broker-workflow", { body: {
        action:"apply", full_name:f.get("full_name"), area_of_operation:f.get("area_of_operation"),
        email:f.get("email"), phone:f.get("phone")
      }});
      if (error || data?.error) throw new Error(data?.error || error.message);
      msg.textContent = "Thank you. Your application has been submitted for admin review.";
      brokerApplyForm.reset();
    } catch (err) { msg.textContent = err.message || "Could not submit application."; }
    finally { button.disabled = false; }
  });

  $("#forgotPassword")?.addEventListener("click", async () => {
    const email = $("#loginForm [name=email]").value.trim().toLowerCase();
    if (!email) { $("#loginMessage").textContent = "Enter your email address first."; return; }
    if (!client) { $("#loginMessage").textContent = "Password recovery is unavailable."; return; }
    const { error } = await client.auth.resetPasswordForEmail(email, { redirectTo: location.origin + location.pathname.replace("index.html","broker-reset.html") });
    $("#loginMessage").textContent = error ? error.message : "If this account exists, a password recovery OTP has been sent to its email.";
  });
  $("#loginForm").addEventListener("submit", async e => {
    e.preventDefault(); const f = new FormData(e.currentTarget);
    if (!client) { $("#loginMessage").textContent = "Supabase configuration is required before login can be enabled."; return; }
    const {data,error} = await client.auth.signInWithPassword({email:f.get("email"),password:f.get("password")});
    if (error) { $("#loginMessage").textContent = error.message; return; }
    const {data:profile,error:profileError} = await client.from("ds_v2_profiles").select("role,active").eq("id",data.user.id).single();
    if (profileError || !profile || !profile.active || !["super_admin","team_member","broker"].includes(profile.role)) {
      await client.auth.signOut(); $("#loginMessage").textContent = "This account is not active or authorised."; return;
    }
    const isBroker = profile.role === "broker";
    if ((requestedLoginRole === "broker" && !isBroker) || (requestedLoginRole === "admin" && isBroker)) {
      await client.auth.signOut(); $("#loginMessage").textContent = requestedLoginRole === "admin" ? "This is not an admin account. Please choose Broker Login." : "This is not a broker account. Please choose Admin Login."; return;
    }
    window.location.href = isBroker ? "broker.html" : "admin.html";  });
})();