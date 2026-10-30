/* Shared navigation and scroll animation controller */
document.querySelectorAll(".year").forEach(el=>el.textContent=new Date().getFullYear());

const toggle=document.querySelector(".menu-toggle");
if(toggle){
  toggle.addEventListener("click",()=>{
    const nav=document.querySelector(".main-nav");
    const open=nav.classList.toggle("open");
    toggle.setAttribute("aria-expanded",String(open));
  });
}
document.querySelectorAll(".main-nav a").forEach(a=>a.addEventListener("click",()=>document.querySelector(".main-nav")?.classList.remove("open")));

const header=document.querySelector(".site-header");
const updateHeader=()=>header?.classList.toggle("is-scrolled",window.scrollY>18);
updateHeader();
window.addEventListener("scroll",updateHeader,{passive:true});

/* Add reveal classes to the meaningful content blocks. */
const revealSelectors=[
  ".section-heading",".location-strip",".property-card",".service-card",
  ".copy-block",".editorial-image",".contact-layout > div",
  ".enquiry-form",".detail-layout > div",".filters",
  ".content-section > p",".contact-direct"
];
revealSelectors.forEach(selector=>{
  document.querySelectorAll(selector).forEach((el,index)=>{
    if(!el.classList.contains("reveal")) el.classList.add("reveal");
    if(el.classList.contains("property-card")||el.classList.contains("service-card")){
      el.style.setProperty("--reveal-delay",`${(index%4)*90}ms`);
    }
  });
});

/* Animate sections as they enter the viewport; reveal immediately if unsupported. */
const revealEls=document.querySelectorAll(".reveal");
if("IntersectionObserver" in window && !window.matchMedia("(prefers-reduced-motion: reduce)").matches){
  const observer=new IntersectionObserver((entries,obs)=>{
    entries.forEach(entry=>{
      if(entry.isIntersecting){
        entry.target.classList.add("is-visible");
        obs.unobserve(entry.target);
      }
    });
  },{threshold:.12,rootMargin:"0px 0px -45px 0px"});
  revealEls.forEach(el=>observer.observe(el));
}else{
  revealEls.forEach(el=>el.classList.add("is-visible"));
}

/* Gentle hero background movement on desktop only. */
const hero=document.querySelector(".home-photo");
if(hero && !window.matchMedia("(prefers-reduced-motion: reduce)").matches && window.matchMedia("(min-width: 900px)").matches){
  let ticking=false;
  window.addEventListener("scroll",()=>{
    if(!ticking){
      window.requestAnimationFrame(()=>{
        const y=Math.min(window.scrollY*.12,70);
        hero.style.transform=`translate3d(0,${y}px,0) scale(1.04)`;
        ticking=false;
      });
      ticking=true;
    }
  },{passive:true});
}
