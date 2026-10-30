document.querySelectorAll(".year").forEach(el=>el.textContent=new Date().getFullYear());
const toggle=document.querySelector(".menu-toggle");if(toggle){toggle.addEventListener("click",()=>{const nav=document.querySelector(".main-nav");const open=nav.classList.toggle("open");toggle.setAttribute("aria-expanded",String(open));});}
document.querySelectorAll(".main-nav a").forEach(a=>a.addEventListener("click",()=>document.querySelector(".main-nav")?.classList.remove("open")));
