/* מסלול שליח – חיבור לשרת (Supabase). המפתח כאן הוא המפתח הציבורי בלבד; ההרשאות נאכפות בשרת (RLS). */
window.CLOUD_CFG = {
  url: "",      // https://xxxx.supabase.co
  anonKey: ""   // public anon key
};
window.Cloud = (function(){
  const cfg = window.CLOUD_CFG;
  const on = !!(cfg.url && cfg.anonKey && window.supabase);
  const sb = on ? window.supabase.createClient(cfg.url, cfg.anonKey, {auth:{persistSession:true, autoRefreshToken:true, storageKey:"courier-auth"}}) : null;
  const phoneDigits = p => String(p||"").replace(/\D/g,"").replace(/^972/,"0");
  const phoneEmail = p => phoneDigits(p) + "@couriers.guy-shlichuyot.app";
  function todayIL(){ return new Date().toLocaleDateString("en-CA",{timeZone:"Asia/Jerusalem"}); }
  async function me(){
    if(!sb) return null;
    const { data:{ user } } = await sb.auth.getUser();
    if(!user) return null;
    const { data, error } = await sb.from("profiles").select("*").eq("id", user.id).maybeSingle();
    if(error) throw error;
    return data ? {...data, email:user.email} : {id:user.id, status:"pending", role:"courier", email:user.email};
  }
  function errText(e){
    const m = (e && (e.message||e.error_description||String(e))) || "";
    if(/Invalid login credentials/i.test(m)) return "מספר טלפון או סיסמה לא נכונים.";
    if(/already registered|already been registered|User already/i.test(m)) return "המספר הזה כבר רשום. נסה להתחבר.";
    if(/Password should be at least/i.test(m)) return "הסיסמה צריכה להיות לפחות 6 תווים.";
    if(/Email not confirmed/i.test(m)) return "החשבון עוד לא אושר במערכת. פנה למנהל.";
    if(/Failed to fetch|NetworkError|network/i.test(m)) return "אין חיבור לאינטרנט. נסה שוב.";
    if(/rate limit/i.test(m)) return "יותר מדי ניסיונות. נסה שוב בעוד דקה.";
    return "שגיאה: " + m;
  }
  return { on, sb, phoneDigits, phoneEmail, todayIL, me, errText };
})();
