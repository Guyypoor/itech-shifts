const V="courier-v3";
const LOCAL=["./","index.html","manifest.webmanifest","geo.json","icon-192.png","icon-512.png","apple-touch-icon.png"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(LOCAL)).then(()=>self.skipWaiting()));});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener("fetch",e=>{
  const r=e.request; if(r.method!=="GET") return;
  const u=new URL(r.url);
  const page=r.mode==="navigate"||u.pathname.endsWith("/index.html");
  if(page){ // network first, so updates arrive; cache when offline
    e.respondWith(fetch(r.url,{cache:"no-cache"}).then(res=>{const c=res.clone();caches.open(V).then(x=>x.put(r,c));return res;}).catch(()=>caches.match(r).then(m=>m||caches.match("index.html"))));
    return;
  }
  // everything else (data, OCR language, CDN libraries, fonts): cache first
  e.respondWith(caches.match(r).then(m=>m||fetch(r).then(res=>{ if(res&&(res.ok||res.type==="opaque")){const c=res.clone();caches.open(V).then(x=>x.put(r,c));} return res;})));
});
