const params=new URLSearchParams(location.search);const id=params.get("id");const p=(window.DREAM_SPACE_PROPERTIES||[]).find(x=>x.id===id);const root=document.getElementById("detailRoot");
if(!p){root.innerHTML='<div><p class="eyebrow">PROPERTY NOT FOUND</p><h1 class="detail-title">This listing may have been updated.</h1><p class="detail-copy">Browse the current collection to explore available properties.</p><a class="button button-dark" href="properties.html">Back to properties ↗</a></div>'; }
else{
document.title=p.title+" | Dream Space Goa";
document.getElementById("detailImage").src=p.image;document.getElementById("detailImage").alt=p.title;
document.getElementById("detailType").textContent=p.typeLabel.toUpperCase();
document.getElementById("detailTitle").textContent=p.title;document.getElementById("detailLocation").textContent=p.location.toUpperCase();
document.getElementById("detailPrice").textContent=p.price;document.getElementById("detailDescription").textContent=p.description;
document.getElementById("detailFeatures").innerHTML=(p.features||[]).map(x=>`<span>${x}</span>`).join("");
document.getElementById("detailWhatsapp").href="https://wa.me/919175065537?text="+encodeURIComponent("Hello Dream Space, I am interested in "+p.title+" in "+p.location+". Please share current price, availability and details.");
}
