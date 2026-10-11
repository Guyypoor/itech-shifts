const V="courier-v11";
const LOCAL=["./","index.html","admin.html","cloud.js","shared.js","manifest.webmanifest","geo.json","icon-192.png","icon-512.png","apple-touch-icon.png"];
const CACHE_HOSTS=[location.host,"cdnjs.cloudflare.com","cdn.jsdelivr.net","fonts.googleapis.com","fonts.gstatic.com"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(LOCAL)).then(()=>self.skipWaiting()));});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener("fetch",e=>{
  const r=e.request; if(r.method!=="GET") return;
  const u=new URL(r.url);
  if(!CACHE_HOSTS.includes(u.host)) return; // map tiles, routing, geocoding: straight to the network
  const page=r.mode==="navigate"||(u.host===location.host&&/(\/|\.html|\.js)$/.test(u.pathname)&&!u.pathname.endsWith("/sw.js"));
  if(page){ // network first so updates arrive; cached copy when offline
    e.respondWith(fetch(r.url,{cache:"no-cache"}).then(res=>{const c=res.clone();caches.open(V).then(x=>x.put(r.url.split("#")[0].split("?")[0],c));return res;}).catch(()=>caches.match(r.url.split("#")[0].split("?")[0]).then(m=>m||caches.match("index.html"))));
    return;
  }
  e.respondWith(caches.match(r).then(m=>m||fetch(r).then(res=>{ if(res&&(res.ok||res.type==="opaque")){const c=res.clone();caches.open(V).then(x=>x.put(r,c));} return res;})));
});
