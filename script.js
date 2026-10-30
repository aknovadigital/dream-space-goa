const WHATSAPP_NUMBER = "919175065537";
const grid = document.getElementById("propertyGrid");
const listings = window.DREAM_SPACE_PROPERTIES || [];
let activeFilter = "all";

function whatsappLink(message) {
  return `https://wa.me/${WHATSAPP_NUMBER}?text=${encodeURIComponent(message)}`;
}
function propertyCard(p) {
  return `<article class="property-card" data-id="${p.id}" tabindex="0" role="button" aria-label="View ${p.title}">
    <div class="property-photo"><img src="${p.image}" alt="${p.title}" loading="lazy"><span class="property-tag">${p.typeLabel}</span><button class="property-save" aria-label="Enquire about ${p.title}" data-enquire="${p.id}">↗</button></div>
    <div class="property-info"><div class="property-location">${p.location}</div><h3>${p.title}</h3><div class="property-meta"><span>${p.beds}</span><span>${p.availability}</span></div><div class="property-price-row"><span class="property-price">${p.price}</span><span class="property-more">View details ↗</span></div></div>
  </article>`;
}
function renderProperties() {
  const query = (document.getElementById("propertySearch").value || "").toLowerCase().trim();
  const filtered = listings.filter(p => (activeFilter === "all" || p.type === activeFilter) &&
    [p.title,p.location,p.area,p.typeLabel].join(" ").toLowerCase().includes(query));
  grid.innerHTML = filtered.length ? filtered.map(propertyCard).join("") : `<div class="empty-state">No matching properties found. <br>Tell us what you're looking for and we'll help you find it.</div>`;
}
function openProperty(id) {
  const p = listings.find(x => x.id === id);
  if (!p) return;
  document.getElementById("modalImage").src = p.image;
  document.getElementById("modalImage").alt = p.title;
  document.getElementById("modalType").textContent = p.typeLabel.toUpperCase();
  document.getElementById("modalTitle").textContent = p.title;
  document.getElementById("modalLocation").textContent = p.location;
  document.getElementById("modalDescription").textContent = p.description;
  document.getElementById("modalPrice").textContent = p.price;
  document.getElementById("modalFeatures").innerHTML = p.features.map(x => `<span>${x}</span>`).join("");
  document.getElementById("modalWhatsApp").href = whatsappLink(`Hello Dream Space, I am interested in: ${p.title} (${p.location}). Please share the latest price, availability and details.`);
  const modal = document.getElementById("propertyModal");
  modal.classList.add("open"); modal.setAttribute("aria-hidden","false"); document.body.style.overflow = "hidden";
}
function closeModal() {
  const modal = document.getElementById("propertyModal");
  modal.classList.remove("open"); modal.setAttribute("aria-hidden","true"); document.body.style.overflow = "";
}
document.querySelectorAll(".filter-tab").forEach(btn => btn.addEventListener("click", () => {
  document.querySelectorAll(".filter-tab").forEach(b => b.classList.remove("active"));
  btn.classList.add("active"); activeFilter = btn.dataset.filter; renderProperties();
}));
document.getElementById("propertySearch").addEventListener("input", renderProperties);
grid.addEventListener("click", e => {
  const enquiry = e.target.closest("[data-enquire]");
  const card = e.target.closest(".property-card");
  if (enquiry) { e.stopPropagation(); const p = listings.find(x=>x.id===enquiry.dataset.enquire); window.open(whatsappLink(`Hello Dream Space, please share details about ${p.title} in ${p.location}.`),"_blank","noopener"); }
  else if (card) openProperty(card.dataset.id);
});
grid.addEventListener("keydown", e => { if ((e.key === "Enter" || e.key === " ") && e.target.classList.contains("property-card")) { e.preventDefault(); openProperty(e.target.dataset.id); }});
document.querySelectorAll("[data-close]").forEach(el => el.addEventListener("click", closeModal));
document.addEventListener("keydown", e => { if (e.key === "Escape") closeModal(); });
document.getElementById("enquiryForm").addEventListener("submit", e => {
  e.preventDefault();
  const data = new FormData(e.currentTarget);
  const message = `Hello Dream Space, I would like to make a property enquiry.\n\nName: ${data.get("name")}\nPhone: ${data.get("phone")}\nInterested in: ${data.get("interest")}\nPreferred location: ${data.get("location") || "Not specified"}\nMessage: ${data.get("message") || "Please contact me."}`;
  window.open(whatsappLink(message), "_blank", "noopener");
});
const menuToggle = document.querySelector(".menu-toggle");
menuToggle.addEventListener("click", () => {
  const nav = document.querySelector(".main-nav"); const open = nav.classList.toggle("open");
  menuToggle.setAttribute("aria-expanded", String(open));
});
document.querySelectorAll(".main-nav a").forEach(a => a.addEventListener("click", () => document.querySelector(".main-nav").classList.remove("open")));
document.getElementById("year").textContent = new Date().getFullYear();
renderProperties();
