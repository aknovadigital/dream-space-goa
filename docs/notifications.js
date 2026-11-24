(()=> {
 const cfg=window.DS_CONFIG||{};
 if(!window.supabase||!cfg.supabaseUrl||!cfg.supabaseAnonKey)return;
 const db=window.supabase.createClient(cfg.supabaseUrl,cfg.supabaseAnonKey);
 let uid=null,channel=null,items=[];
 const esc=v=>String(v??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
 const style=document.createElement("style");
 style.textContent=`
 .ds-notify{position:relative;display:inline-flex;align-items:center;z-index:30}
 .ds-notify-trigger{position:relative;width:42px;height:42px;border:1px solid var(--line,#ddd6c1);border-radius:5px;background:#fff;color:var(--teal,#073e52);font-size:21px;cursor:pointer}
 .ds-notify-count{position:absolute;top:-5px;right:-5px;min-width:18px;height:18px;padding:0 4px;border-radius:20px;background:#b43d36;color:#fff;font:700 10px/18px Arial;text-align:center}
 .ds-notify-panel{position:absolute;right:0;top:50px;width:min(370px,calc(100vw - 28px));max-height:min(520px,75vh);overflow:auto;background:#fff;border:1px solid var(--line,#ddd6c1);box-shadow:0 15px 45px #092e3b2b;border-radius:6px;color:var(--ink,#123b4a)}
 .ds-notify-head{position:sticky;top:0;background:#fff;padding:14px 15px;border-bottom:1px solid var(--line,#ddd6c1);display:flex;justify-content:space-between;align-items:center;gap:8px}
 .ds-notify-head strong{font:22px Georgia;color:var(--teal,#073e52)}
 .ds-notify-head button,.ds-notify-item button{border:0;background:none;color:var(--teal,#073e52);cursor:pointer;font-size:11px}
 .ds-notify-item{display:block;width:100%;padding:13px 15px;border:0;border-bottom:1px solid #eee9dc;background:#fff;text-align:left;color:inherit;cursor:pointer}
 .ds-notify-item.unread{background:#f5f3e8}
 .ds-notify-item strong{display:block;font-size:12px;margin-bottom:5px}
 .ds-notify-item span{display:block;font-size:11px;line-height:1.5;color:#68777a}
 .ds-notify-item small{display:block;margin-top:7px;color:#8a8f8d;font-size:10px}
 .ds-notify-empty{padding:25px 15px;text-align:center;color:#68777a;font-size:12px}
 @media(max-width:700px){.ds-notify-panel{right:-4px;top:47px}}
 `;
 document.head.append(style);
 function host(){return document.querySelector(".topbar")||document.querySelector(".header");}
 function build(){const h=host();if(!h||document.querySelector(".ds-notify"))return;
 const wrap=document.createElement("div");wrap.className="ds-notify";wrap.innerHTML='<button class="ds-notify-trigger" type="button" aria-label="Notifications">🔔<span class="ds-notify-count" hidden>0</span></button><div class="ds-notify-panel" hidden><div class="ds-notify-head"><strong>Notifications</strong><button type="button" class="ds-notify-all">Mark all as read</button></div><div class="ds-notify-list"></div></div>';
 h.append(wrap);const trigger=wrap.querySelector(".ds-notify-trigger"),panel=wrap.querySelector(".ds-notify-panel");
 trigger.addEventListener("click",()=>{panel.hidden=!panel.hidden;if(!panel.hidden)load()});
 document.addEventListener("click",e=>{if(!wrap.contains(e.target))panel.hidden=true});
 wrap.querySelector(".ds-notify-all").onclick=async()=>{if(!uid)return;const ids=items.filter(x=>!x.read_at).map(x=>x.id);if(!ids.length)return;await db.from("ds_v2_notifications").update({read_at:new Date().toISOString()}).in("id",ids);await load()};
 }
 function draw(){const wrap=document.querySelector(".ds-notify");if(!wrap)return;const unread=items.filter(x=>!x.read_at).length,count=wrap.querySelector(".ds-notify-count");count.textContent=unread>99?"99+":String(unread);count.hidden=!unread;
 const list=wrap.querySelector(".ds-notify-list");list.innerHTML=items.length?items.map(n=>'<button type="button" class="ds-notify-item '+(!n.read_at?"unread":"")+'" data-notice="'+n.id+'"><strong>'+esc(n.title)+'</strong><span>'+esc(n.message)+'</span><small>'+new Date(n.created_at).toLocaleString()+(n.read_at?" · Read":" · Unread")+'</small></button>').join(""):'<div class="ds-notify-empty">No notifications yet.</div>';
 list.querySelectorAll("[data-notice]").forEach(b=>b.onclick=async()=>{const n=items.find(x=>x.id===b.dataset.notice);if(n&&!n.read_at){await db.from("ds_v2_notifications").update({read_at:new Date().toISOString()}).eq("id",n.id);n.read_at=new Date().toISOString();draw()}const panel=wrap.querySelector(".ds-notify-panel");panel.hidden=true;if(n?.entity_type==="submission"&&location.pathname.endsWith("admin.html"))document.querySelector('[data-extra-view="submissions"]')?.click();else if(n?.entity_type==="lead"&&location.pathname.endsWith("admin.html"))document.querySelector('[data-view="leads"]')?.click();else if(n?.entity_type==="property"&&location.pathname.endsWith("broker.html"))document.querySelector('[data-tab="inventory"]')?.click()});
 }
 async function load(){if(!uid)return;const r=await db.from("ds_v2_notifications").select("id,title,message,entity_type,entity_id,created_at,read_at").eq("user_id",uid).order("created_at",{ascending:false}).limit(100);if(r.error){console.warn("Notifications unavailable:",r.error.message);return}items=r.data||[];draw()}
 async function init(session){if(!session?.user){uid=null;if(channel)db.removeChannel(channel);channel=null;return}uid=session.user.id;build();await load();if(channel)db.removeChannel(channel);channel=db.channel("ds-notifications-"+uid).on("postgres_changes",{event:"*",schema:"public",table:"ds_v2_notifications",filter:"user_id=eq."+uid},()=>load()).subscribe()}
 db.auth.onAuthStateChange((event,session)=>{if(session)setTimeout(()=>init(session),0);else init(null)});
 db.auth.getSession().then(({data})=>init(data.session));
})();