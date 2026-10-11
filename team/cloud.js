/* משמרות אייטק – חיבור לשרת (Supabase). זה המפתח הציבורי בלבד; ההרשאות נאכפות בשרת (RLS). */
window.CLOUD_CFG = {
  url: "https://ifvtcmnhaivdagztrrrl.supabase.co",
  anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlmdnRjbW5oYWl2ZGFnenRycnJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE3MTk5MjcsImV4cCI6MjEwNzI5NTkyN30.EhL0HsVu8PgqSdUPI-7eA9uf55pjyZ_RiWvI58G3jcQ"
};
window.Cloud = (function () {
  const cfg = window.CLOUD_CFG;
  const on = !!(cfg.url && cfg.anonKey && window.supabase);
  const sb = on ? window.supabase.createClient(cfg.url, cfg.anonKey, { auth: { persistSession: true, autoRefreshToken: true, storageKey: "itech-shifts-auth" } }) : null;
  const phoneDigits = p => String(p || "").replace(/\D/g, "").replace(/^972/, "0");
  const phoneEmail = p => phoneDigits(p) + "@staff.itech-shifts.app";
  const DAYS = ["ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי"];
  function todayIL() { return new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Jerusalem" }); }
  function addDays(iso, n) { const d = new Date(iso + "T12:00:00Z"); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); }
  function dowIL(iso) { return new Date(iso + "T12:00:00Z").getUTCDay(); }
  // the week employees submit for = the Sunday after today (same rule as the server)
  function targetWeek() { const t = todayIL(); return addDays(t, 7 - dowIL(t)); }
  function thisWeek() { const t = todayIL(); return addDays(t, -dowIL(t)); }
  function ddmm(iso) { return iso.slice(8, 10) + "/" + iso.slice(5, 7); }
  function weekLabel(ws) { return ddmm(ws) + "–" + ddmm(addDays(ws, 5)); }
  // 11 shifts: Sun–Thu morning+afternoon, Fri morning
  function shiftLabel(ws, i) { const d = Math.floor(i / 2); return DAYS[d] + " " + ddmm(addDays(ws, d)) + " · " + (i % 2 ? "צהריים" : "בוקר"); }
  async function me() {
    if (!sb) return null;
    const { data: { user } } = await sb.auth.getUser();
    if (!user) return null;
    const { data, error } = await sb.from("profiles").select("*").eq("id", user.id).maybeSingle();
    if (error) throw error;
    return data ? { ...data, email: user.email } : { id: user.id, status: "pending", role: "employee", email: user.email };
  }
  function errText(e) {
    const m = (e && (e.message || e.error_description || String(e))) || "";
    if (/Invalid login credentials/i.test(m)) return "מספר טלפון או סיסמה לא נכונים.";
    if (/already registered|already been registered|User already/i.test(m)) return "המספר הזה כבר רשום. נסה/י להתחבר.";
    if (/Password should be at least/i.test(m)) return "הסיסמה צריכה להיות לפחות 6 תווים.";
    if (/Email not confirmed/i.test(m)) return "החשבון עוד לא אושר במערכת. פנה/י לגיא.";
    if (/Failed to fetch|NetworkError|network/i.test(m)) return "אין חיבור לאינטרנט. נסה/י שוב.";
    if (/rate limit/i.test(m)) return "יותר מדי ניסיונות. נסה/י שוב בעוד דקה.";
    if (/row-level security/i.test(m)) return "אין הרשאה לפעולה הזו.";
    return "שגיאה: " + m;
  }
  return { on, sb, phoneDigits, phoneEmail, DAYS, todayIL, addDays, targetWeek, thisWeek, ddmm, weekLabel, shiftLabel, me, errText };
})();
