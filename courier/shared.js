/* shared by index.html (courier) and admin.html – generated from index.html */
function hhmm(t){ const m=String(t||"").match(/^(\d{1,2})(?::(\d{2}))?$/); if(!m) return ""; const H=+m[1], M=+(m[2]||0); if(H>23||M>59) return ""; return String(H).padStart(2,"0")+":"+String(M).padStart(2,"0"); }
function parseFlags(text){
  const t=String(text||""); const f={urgent:/דחוף|בהול|אקספרס/.test(t),after:"",before:""};
  let m=t.match(/בין\s*(?:השעות\s*)?(\d{1,2}(?::\d{2})?)\s*[-–ל]\s*(\d{1,2}(?::\d{2})?)/); if(m){ f.after=hhmm(m[1]); f.before=hhmm(m[2]); }
  m=t.match(/(?:אחרי|לא לפני|החל מ-?)\s*(?:השעה\s*)?(\d{1,2}:\d{2}|\d{1,2}(?=\s|$))/); if(m&&!f.after) f.after=hhmm(m[1]);
  m=t.match(/(?<!לא\s)(?:עד|לפני)\s*(?:השעה\s*)?(\d{1,2}:\d{2}|\d{1,2}(?=\s|$))/); if(m&&!f.before) f.before=hhmm(m[1]);
  return f;
}
function cleanFlags(t){ return String(t||"").replace(/דחוף!*|בהול|אקספרס/g,"").replace(/(בין\s*(השעות\s*)?\d{1,2}(:\d{2})?\s*[-–ל]\s*\d{1,2}(:\d{2})?|(אחרי|לא לפני|עד|לפני)\s*(השעה\s*)?\d{1,2}(:\d{2})?)/g,"").replace(/\s{2,}/g," ").replace(/^[\s,–-]+|[\s,–-]+$/g,"").trim(); }
function secOfDay(hm){ const m=String(hm||"").match(/^(\d{2}):(\d{2})$/); return m?(+m[1])*3600+(+m[2])*60:null; }
function clock(ms){ return new Date(ms).toLocaleTimeString("he-IL",{hour:"2-digit",minute:"2-digit"}); }
function hasCity(a){ a=a||""; return /,/.test(a) || /\d+[א-ת]?\s+[א-תA-Za-z"'׳-]{2,}/.test(a); }
const PHONE_RE=/(?:\+?972[-\s]?|0)(?:5\d|[2-489]|7\d)[-\s]?\d{3}[-\s]?\d{4}/;
function cleanLine(l){
  l=l.replace(/‏|‎|‪|‫|‬|⁨|⁩/g,"").trim();
  l=l.replace(/^\[?\d{1,2}[./]\d{1,2}[./]\d{2,4},?\s*\d{1,2}:\d{2}(?::\d{2})?\]?\s*(?:-\s*)?/,"");
  l=l.replace(/^[^:\d]{1,30}:\s+/,"");          // sender name before colon
  l=l.replace(/^(\d{1,2}[.)]|[-•*–])\s*/,"");    // list markers
  return l.trim();
}
function parseWhatsApp(text){
  const out=[]; let pendingName="";
  for(const raw0 of text.split(/\r?\n/)){
    const fl=parseFlags(raw0.replace(/^\[[^\]]*\]/,"")); const raw=cleanFlags(raw0);
    let l=cleanLine(raw).replace(/\b\d{1,2}:\d{2}(?::\d{2})?\b/g," ").replace(/\b\d{1,2}[./]\d{1,2}[./]\d{2,4}\b/g," ").replace(/[|_~^`]+/g," ").replace(/\s{2,}/g," ").trim();
    if(!l||/המדיה הושמטה|הודעה זו נמחקה|image omitted|<.*>/.test(l)) continue;
    let phone=""; const m=l.match(PHONE_RE);
    if(m){ phone=m[0].replace(/\s/g,""); l=l.replace(m[0]," ").replace(/\s{2,}/g," ").trim(); }
    if(!/\d/.test(l)){                           // no house number: probably a name line
      if(l.length<=30){ if(/[א-תA-Za-z]{2,}/.test(l)) pendingName=l; if(phone&&out.length&&!out[out.length-1].phone&&!pendingName) out[out.length-1].phone=phone; continue; }
    }
    let name=pendingName; pendingName="";
    const dash=l.split(/\s+[–-]\s+/);
    if(dash.length===2){
      const [a,b]=dash; if(!/\d/.test(a)&&/\d/.test(b)){ name=name||a.trim(); l=b.trim(); }
      else if(/\d/.test(a)&&!/\d/.test(b)&&b.length<=30){ name=name||b.trim(); l=a.trim(); }
    }
    l=l.replace(/[,\s]+$/,"");
    if(!/[א-ת]{2,}/.test(l)||!/\d/.test(l)) continue;
    if(l) out.push({addr:l, city:"", name, phone, note:"", urgent:fl.urgent, after:fl.after, before:fl.before});
  }
  return out;
}

let GEOP=null;
function gnorm(t){
  return String(t||"").replace(/[\u0591-\u05C7]/g,"").replace(/["'׳״`.]/g,"").replace(/[-–־_/]/g," ")
    .replace(/קריית/g,"קרית").replace(/\s+/g," ").trim();
}
const CITY_ALIAS={"פרדס חנה כרכור":"פרדס חנה-כרכור","זכרון":"זכרון יעקב","אור עקיבה":"אור עקיבא","יוקנעם":"יקנעם עילית","יקנעם":"יקנעם עילית","קרית טבעון":"קריית טבעון","טבעון":"קריית טבעון","באקה":"באקה אל-גרביה","ג'סר":"ג'סר א-זרקא","גבעת עדה":"גבעת עדה","בנימינה גבעת עדה":"בנימינה","פרדס-חנה":"פרדס חנה"};
function loadGeo(){
  if(!GEOP) GEOP=fetch(new URL("geo.json",location.href).href).then(r=>{ if(!r.ok) throw new Error("geo"); return r.json(); }).then(d=>{
    const locs=d.loc.map(([n,lat,lon])=>({n:gnorm(n),name:n,lat,lon}));
    const byName=new Map(locs.map(l=>[l.n,l]));
    for(const [a,b] of Object.entries(CITY_ALIAS)){ const t=byName.get(gnorm(b)); if(t&&!byName.has(gnorm(a))) locs.push({n:gnorm(a),name:t.name,lat:t.lat,lon:t.lon}); }
    const uniq=d.loc.map(([n,lat,lon])=>({name:n,lat,lon}));
    locs.sort((a,b)=>b.n.length-a.n.length);
    const st=new Map(); for(const [n,pts] of d.st){ const k=gnorm(n); st.set(k,(st.get(k)||[]).concat(pts)); }
    return {locs,st,uniq};
  }).catch(()=>{ GEOP=null; return null; });
  return GEOP;
}
function km(a,b){ const R=6371,r=Math.PI/180,dLa=(b.lat-a.lat)*r,dLo=(b.lon-a.lon)*r; const h=Math.sin(dLa/2)**2+Math.cos(a.lat*r)*Math.cos(b.lat*r)*Math.sin(dLo/2)**2; return 2*R*Math.asin(Math.sqrt(h)); }
// rough town radius (km) so big towns "own" their streets against small neighbours; default 0.7
const TOWN_R={"חיפה":6,"נתניה":4.5,"חדרה":3.8,"הרצליה":3.5,"כפר סבא":3,"רעננה":3,"הוד השרון":2.5,"רמת השרון":2.5,"פרדס חנה-כרכור":2.6,"פרדס חנה":1.8,"כרכור":1.5,"זכרון יעקב":2,"אור עקיבא":1.6,"בנימינה":1.4,"קיסריה":2.5,"אום אל-פחם":2.5,"באקה אל-גרביה":2,"טייבה":2.2,"טירה":1.6,"קלנסווה":1.4,"כפר יונה":1.6,"אבן יהודה":1.5,"קדימה":1.3,"צורן":1.2,"תל מונד":1.3,"חריש":2,"יקנעם עילית":2,"טירת כרמל":1.8,"נשר":1.8,"קריית טבעון":1.8,"קרית אתא":2.2,"קריית ביאליק":1.6,"קריית מוצקין":1.5,"קריית ים":1.5,"מגדל העמק":1.8,"עפולה":2.5,"כפר קרע":1.4,"ערערה":1.4,"ג'סר א-זרקא":0.9,"פוריידיס":0.9,"עתלית":1.1,"גבעת אולגה":1.2,"בית אליעזר":0.9};
const TOWN_GROUP=[["פרדס חנה-כרכור","פרדס חנה","כרכור"],["חדרה","גבעת אולגה","בית אליעזר","אולגה"],["בנימינה","גבעת עדה"],["קדימה","צורן"]];
function groupOf(name){ const g=TOWN_GROUP.find(x=>x.includes(name)); return g||[name]; }
function ownerOf(G,p){ // weighted nearest locality
  let best=null,bv=1e9; for(const l of G.uniq){ const v=km(p,l)-(TOWN_R[l.name]||0.7); if(v<bv){bv=v;best=l;} } return best;
}
function findCity(G,text){
  const t=" "+gnorm(text)+" ";
  for(const l of G.locs){ if(l.n.length>=2 && t.includes(" "+l.n+" ")) return l; }
  for(const l of G.locs){ if(l.n.length>=4 && t.includes(l.n)) return l; }
  return null;
}
function geocode(G,text,fallbackCity,near){
  let city=findCity(G,text);
  const usedCity=!!city;
  if(!city&&fallbackCity) city=findCity(G,fallbackCity);
  let rest=" "+gnorm(text)+" ";
  if(usedCity) rest=rest.replace(" "+city.n+" "," ").replace(city.n," ");
  rest=rest.replace(/\b(דירה|דיר|קומה|כניסה|ת ד|מיקוד)\b.*$/,"").replace(/,/g," ");
  let street=rest.replace(/\d+[א-ת]?/g," ").replace(/^\s*(רחוב|רח|שד)\s+/," ").replace(/\s+/g," ").trim();
  street=street.replace(/^(רחוב|רח)\s+/,"").replace(/^שד\s+/,"שדרות ");
  const ref=city||near||null;
  let pts=null;
  if(street){
    pts=G.st.get(street)||G.st.get("ה"+street)||(street.startsWith("ה")?G.st.get(street.slice(1)):null)||G.st.get("רחוב "+street)||G.st.get("שדרות "+street);
    if(!pts&&street.length>=4){ for(const [k,v] of G.st){ if(k.endsWith(" "+street)||k===street){ pts=v; break; } } }
  }
  if(pts&&pts.length){
    const cand=pts.map(([lat,lon])=>({lat,lon}));
    if(city){ const grp=groupOf(city.name); const own=cand.filter(c=>{ const o=ownerOf(G,c); return o&&grp.includes(o.name); }); if(own.length){ cand.length=0; cand.push(...own); } else { cand.length=0; } }
    if(cand.length&&ref){ cand.sort((a,b)=>km(a,ref)-km(b,ref)); if(!city||km(cand[0],ref)<7){ const inC=cand.filter(c=>km(c,cand[0])<3); const m={lat:inC.reduce((s,c)=>s+c.lat,0)/inC.length,lon:inC.reduce((s,c)=>s+c.lon,0)/inC.length}; inC.sort((a,b)=>km(a,m)-km(b,m)); return {lat:inC[0].lat,lon:inC[0].lon,q:"street"}; } }
    else if(cand.length===1) return {...cand[0],q:"street"};
  }
  if(city&&(usedCity||!hasCity(text))) return {lat:city.lat,lon:city.lon,q:"city"};
  return null;
}
/* ---------- precise (house-number) geocoding via OpenStreetMap Nominatim ---------- */
// Only "street number, city" is sent – never names, phones or notes. Results are cached on the phone.
const GC_KEY="courier-geocache-v2"; let GC=null, gcLast=0, gcOffline=false;
function gcLoad(){ if(GC) return GC; try{ GC=JSON.parse(localStorage.getItem(GC_KEY)||"{}"); }catch(e){ GC={}; } return GC; }
function gcSave(){ try{ const k=Object.keys(GC); if(k.length>800) k.slice(0,k.length-800).forEach(x=>delete GC[x]); localStorage.setItem(GC_KEY,JSON.stringify(GC)); }catch(e){} }
function splitAddr(text,defCity){
  const junk=/(^|\s)(דירה|דיר|קומה|כניסה|מיקוד|ד'|ק')(\s|\d|$).*$/;
  const parts=String(text||"").split(",").map(x=>x.replace(junk,"").trim()).filter(x=>x&&!/^(דירה|קומה|כניסה)/.test(x));
  let street=parts[0]||"", city=parts.length>1?parts[parts.length-1]:"";
  if(!city){ const m=street.match(/^(.*?\d+[א-ת]?)\s+([א-ת].*)$/); if(m){ street=m[1]; city=m[2]; } }
  if(!city) city=defCity||"";
  street=street.replace(/^(רחוב|רח['׳]?)\s+/,"").trim();
  return {street,city:city.trim()};
}
function cityOk(G,city,lat,lon,addr){
  const c=G&&findCity(G,city);
  if(c){ const grp=groupOf(c.name); const r=Math.max(...grp.map(n=>TOWN_R[n]||0.8))+3; return km({lat,lon},c)<=r; }
  const n=gnorm(city); if(!n) return true;
  return Object.values(addr||{}).some(v=>gnorm(String(v)).includes(n)||n.includes(gnorm(String(v))));
}
async function nomi(params){
  const wait=gcLast+1100-Date.now(); if(wait>0) await new Promise(r=>setTimeout(r,wait)); gcLast=Date.now();
  const ctl=new AbortController(); const t=setTimeout(()=>ctl.abort(),8000);
  try{
    const r=await fetch("https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=3&countrycodes=il&accept-language=he&"+params,{signal:ctl.signal});
    if(!r.ok) throw new Error("http"); return await r.json();
  }finally{ clearTimeout(t); }
}
async function preciseGeocode(G,text,defCity){
  const {street,city}=splitAddr(text,defCity); if(!street) return null;
  const key=gnorm(street+"|"+city); const C=gcLoad();
  if(C[key]!==undefined) return C[key];
  if(gcOffline) return null;
  const hasNum=/\d/.test(street);
  let res=null;
  try{
    const tries=[];
    const OSM_CITY={"בנימינה":"בנימינה-גבעת עדה","גבעת עדה":"בנימינה-גבעת עדה","פרדס חנה":"פרדס חנה-כרכור","כרכור":"פרדס חנה-כרכור","קדימה":"קדימה-צורן","צורן":"קדימה-צורן","תל אביב":"תל אביב-יפו","יפו":"תל אביב-יפו","זכרון":"זכרון יעקב","יקנעם":"יקנעם עילית","טבעון":"קריית טבעון","באקה":"באקה אל-גרביה"};
    const oc=OSM_CITY[gnorm(city)]||OSM_CITY[city.trim()];
    if(oc) tries.push("street="+encodeURIComponent(street)+"&city="+encodeURIComponent(oc));
    if(city) tries.push("street="+encodeURIComponent(street)+"&city="+encodeURIComponent(city));
    tries.push("q="+encodeURIComponent(street+(city?", "+city:"")));
    for(const q of tries){
      const arr=await nomi(q);
      for(const x of arr||[]){
        const lat=+x.lat, lon=+x.lon; if(!isFinite(lat)) continue;
        if(city&&!cityOk(G,city,lat,lon,x.address)) continue;           // wrong town – ignore
        const house=!!(x.address&&x.address.house_number)||/building|house|place/.test(x.addresstype||"");
        const road=/road|street|pedestrian|residential/.test(x.addresstype||"")||!!(x.address&&x.address.road);
        if(house&&hasNum){ res={lat,lon,q:"house"}; break; }
        if(road&&!res) res={lat,lon,q:"street"};
      }
      if(res&&res.q==="house") break;
    }
  }catch(e){ gcOffline=true; return null; }
  C[key]=res; gcSave(); return res;
}
