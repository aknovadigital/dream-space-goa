(() => {
  const cfg = window.DS_CONFIG || {};
  const client = (window.supabase && cfg.supabaseUrl && cfg.supabaseAnonKey && !cfg.supabaseUrl.includes("YOUR-PROJECT"))
    ? window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey) : null;
  const $ = (s) => document.querySelector(s);
  $("#year").textContent = new Date().getFullYear();
  function openLogin() {
    $("#loginTitle").textContent = "Partner sign in";
    $("#loginMessage").textContent = "";
    $("#adminDialog").showModal();
  }
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

  document.addEventListener("click", e => {\n    const link=e.target.closest("a[href^=\\\"tel:\\\"],a[href*=\\\"wa.me\\\"]");\n    if(!link||!client)return;\n    const interaction_type=link.href.startsWith("tel:")?"call_click":"whatsapp_click";\n    client.from("ds_v2_site_interactions").insert({interaction_type,page_path:location.pathname}).then(({error})=>{if(error)console.warn("Interaction tracking unavailable:",error.message)});\n  });\n\n  $("#enquiryForm").addEventListener("submit", async e => {
    e.preventDefault(); const f = new FormData(e.currentTarget);
    const payload = {full_name:f.get("full_name"),phone:f.get("phone"),email:f.get("email") || null,requirement_type:f.get("requirement_type"),notes:f.get("message") || null,source:"website"};
    if (!client) { $("#formMessage").textContent = "Website enquiry is not connected yet. Please contact us on WhatsApp."; return; }
    const {error} = await client.from("ds_v2_leads").insert(payload);
    $("#formMessage").textContent = error ? "We could not submit your enquiry. Please try again or contact us directly." : "Thank you. Your enquiry has been received.";
    if (!error) e.currentTarget.reset();
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
    window.location.href = profile.role === "broker" ? "broker.html" : "admin.html";  });
})();