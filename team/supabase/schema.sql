-- I-TECH Shifts – Supabase schema (project itech-shifts, ref ifvtcmnhaivdagztrrrl)
-- Exported from the live database on 11/10/2026 via team/supabase/export_schema.sql (read-only query).
-- Schema only – no data, no secrets. The ha_token value lives in public.settings (k='ha_token') and is NOT here.
-- Order: sequence → tables → constraints → index → functions → view → triggers → RLS → policies → grants.
-- To rebuild on a fresh Supabase project: run this whole file in the SQL Editor (auth schema already exists in Supabase).

set check_function_bodies = off;  -- same as pg_dump: SQL functions reference each other

create sequence if not exists public.punches_id_seq;

create table if not exists public.availability ( week_start date not null, staff_name text not null, off boolean default false not null, flags boolean[] default array_fill(false, ARRAY[11]) not null, note text default ''::text not null, updated_at timestamp with time zone default now() not null );

create table if not exists public.profiles ( id uuid not null, phone text, staff_name text, role text default 'employee'::text not null, status text default 'pending'::text not null, avatar text, clock_mode text default 'store'::text not null, clock_mode_date date, created_at timestamp with time zone default now() not null, last_seen timestamp with time zone );

create table if not exists public.punches ( id bigint default nextval('punches_id_seq'::regclass) not null, staff_name text not null, action text not null, at timestamp with time zone default now() not null, dist integer, acc integer, remote boolean default false not null, device text, by_admin boolean default false not null, note text );

create table if not exists public.settings ( k text not null, v jsonb not null );

create table if not exists public.staff ( name text not null, color text default '#6B6F8E'::text not null, fg text default '#FFFFFF'::text not null, sort integer default 0 not null, active boolean default true not null );

create table if not exists public.weeks ( week_start date not null, final jsonb, published boolean default false not null, published_at timestamp with time zone, updated_at timestamp with time zone default now() not null );

alter table availability add constraint availability_flags_check CHECK ((array_length(flags, 1) = 11));

alter table availability add constraint availability_pkey PRIMARY KEY (week_start, staff_name);

alter table profiles add constraint profiles_clock_mode_check CHECK ((clock_mode = ANY (ARRAY['store'::text, 'remote'::text, 'off'::text])));

alter table profiles add constraint profiles_pkey PRIMARY KEY (id);

alter table profiles add constraint profiles_role_check CHECK ((role = ANY (ARRAY['employee'::text, 'admin'::text])));

alter table profiles add constraint profiles_staff_name_key UNIQUE (staff_name);

alter table profiles add constraint profiles_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'blocked'::text])));

alter table punches add constraint punches_action_check CHECK ((action = ANY (ARRAY['in'::text, 'out'::text])));

alter table punches add constraint punches_pkey PRIMARY KEY (id);

alter table settings add constraint settings_pkey PRIMARY KEY (k);

alter table staff add constraint staff_pkey PRIMARY KEY (name);

alter table weeks add constraint weeks_pkey PRIMARY KEY (week_start);

alter table availability add constraint availability_staff_name_fkey FOREIGN KEY (staff_name) REFERENCES staff(name) ON UPDATE CASCADE ON DELETE CASCADE;

alter table profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table profiles add constraint profiles_staff_name_fkey FOREIGN KEY (staff_name) REFERENCES staff(name) ON UPDATE CASCADE ON DELETE SET NULL;

alter table punches add constraint punches_staff_name_fkey FOREIGN KEY (staff_name) REFERENCES staff(name) ON UPDATE CASCADE;

CREATE INDEX punches_staff_at ON public.punches USING btree (staff_name, at DESC);

CREATE OR REPLACE FUNCTION public.admin_delete_user(p_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'auth' AS $function$ begin if not public.is_admin() then raise exception 'not allowed'; end if; if p_id = auth.uid() then raise exception 'cannot delete yourself'; end if; delete from auth.users where id = p_id; end $function$;

CREATE OR REPLACE FUNCTION public.clock_state() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ declare n text := public.my_staff(); begin if n is null then return jsonb_build_object('ok', false, 'error', 'החשבון לא פעיל'); end if; return public.clock_state_for(n); end $function$;

CREATE OR REPLACE FUNCTION public.clock_state_for(p_name text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ declare l record; pr profiles; isin boolean; begin select * into pr from profiles where staff_name = p_name; select action, at into l from punches where staff_name = p_name order by at desc limit 1; isin := l.action = 'in' and now() - l.at < interval '16 hours'; return jsonb_build_object('ok', true, 'name', p_name, 'in', coalesce(isin,false), 'since', case when isin then l.at end, 'mode', coalesce(public.eff_mode(pr), 'store')); end $function$;

CREATE OR REPLACE FUNCTION public.dist_m(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision) RETURNS integer LANGUAGE sql IMMUTABLE AS $function$ select round(2 * 6371000 * asin(sqrt(power(sin(radians(lat2-lat1)/2),2) + cos(radians(lat1))*cos(radians(lat2))*power(sin(radians(lon2-lon1)/2),2))))::int $function$;

CREATE OR REPLACE FUNCTION public.eff_mode(p profiles) RETURNS text LANGUAGE sql STABLE AS $function$ select case when p.clock_mode = 'remote' and p.clock_mode_date is distinct from public.il_today() then 'store' else p.clock_mode end $function$;

CREATE OR REPLACE FUNCTION public.ha_ok(p_token text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ select exists(select 1 from settings where k = 'ha_token' and v #>> '{}' = p_token) $function$;

CREATE OR REPLACE FUNCTION public.ha_report(p_token text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ declare tw date := public.target_week(); r jsonb; begin if not public.ha_ok(p_token) then return jsonb_build_object('ok', false, 'error', 'אין הרשאה'); end if; select jsonb_build_object( 'ok', true, 'updated', to_char(now() at time zone 'Asia/Jerusalem', 'DD/MM HH24:MI'), 'today', to_char(public.il_today(), 'DD/MM/YYYY'), 'week', to_char(tw, 'DD/MM') || '–' || to_char(tw + 5, 'DD/MM'), 'total', (select count(*) from staff where active), 'submitted', (select count(*) from availability a join staff s on s.name = a.staff_name and s.active where a.week_start = tw and (a.off or true = any(a.flags))), 'people', (select coalesce(jsonb_object_agg(s.name, jsonb_build_object( 'submitted', coalesce(a.off or true = any(a.flags), false), 'off', coalesce(a.off,false), 'count', coalesce((select count(*) from unnest(a.flags) f where f), 0), 'note', coalesce(a.note,''), 'mode', coalesce((select public.eff_mode(p) from profiles p where p.staff_name = s.name), 'store'), 'app', exists(select 1 from profiles p where p.staff_name = s.name and p.status = 'active'))), '{}'::jsonb) from staff s left join availability a on a.staff_name = s.name and a.week_start = tw where s.active), 'count_in', (select count(*) from staff s where (public.clock_state_for(s.name)->>'in')::boolean), 'in_now', (select coalesce(jsonb_agg(jsonb_build_object('n', x.name, 'since', to_char(x.since at time zone 'Asia/Jerusalem', 'HH24:MI'), 'mins', round(extract(epoch from now() - x.since) / 60))), '[]'::jsonb) from (select s.name, (public.clock_state_for(s.name)->>'since')::timestamptz as since from staff s where (public.clock_state_for(s.name)->>'in')::boolean) x), 'events', (select coalesce(jsonb_agg(jsonb_build_object('t', to_char(at at time zone 'Asia/Jerusalem','HH24:MI'), 'n', staff_name, 'a', case action when 'in' then 'כניסה' else 'יציאה' end) order by at), '[]'::jsonb) from punches where (at at time zone 'Asia/Jerusalem')::date = public.il_today()), 'shifts_today', (select coalesce(jsonb_agg(jsonb_build_object('n', staff_name, 'inn', to_char(t_in at time zone 'Asia/Jerusalem','HH24:MI'), 'out', coalesce(to_char(t_out at time zone 'Asia/Jerusalem','HH24:MI'), ''), 'h', coalesce(hours::text, ''), 'note', coalesce(flag, '')) order by t_in), '[]'::jsonb) from sessions where day = public.il_today()), 'month_label', to_char(public.il_today(), 'MM/YYYY'), 'month', (select coalesce(jsonb_object_agg(staff_name, h), '{}'::jsonb) from ( select staff_name, round(sum(hours),2) h from sessions where date_trunc('month', day) = date_trunc('month', public.il_today()) and hours is not null group by staff_name) m) ) into r; return r; end $function$;

CREATE OR REPLACE FUNCTION public.ha_save_draft(p_token text, p_week date, p_final jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$ begin if not public.ha_ok(p_token) then return jsonb_build_object('ok', false, 'error', 'אין הרשאה'); end if; insert into weeks(week_start, final, published, updated_at) values (p_week, p_final, false, now()) on conflict (week_start) do update set final = excluded.final, updated_at = now() where weeks.published = false; return jsonb_build_object('ok', true); end $function$;

CREATE OR REPLACE FUNCTION public.ha_set_mode(p_token text, p_name text, p_mode text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$ begin if not public.ha_ok(p_token) then return jsonb_build_object('ok', false, 'error', 'אין הרשאה'); end if; if p_mode not in ('store','remote','off') then return jsonb_build_object('ok', false, 'error', 'מצב לא מוכר'); end if; update profiles set clock_mode = p_mode, clock_mode_date = public.il_today() where staff_name = p_name; if not found then return jsonb_build_object('ok', false, 'error', 'לעובד/ת אין חשבון פעיל'); end if; return public.ha_report(p_token); end $function$;

CREATE OR REPLACE FUNCTION public.ha_week(p_token text, p_week date DEFAULT NULL::date) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ declare w date := coalesce(p_week, public.target_week()); begin if not public.ha_ok(p_token) then return jsonb_build_object('ok', false, 'error', 'אין הרשאה'); end if; return jsonb_build_object('ok', true, 'week_start', w, 'names', (select jsonb_agg(name order by sort, name) from staff where active), 'availability', (select coalesce(jsonb_object_agg(staff_name, jsonb_build_object('off', off, 'flags', to_jsonb(flags), 'note', note, 'updated_at', updated_at)), '{}'::jsonb) from availability where week_start = w), 'week', (select to_jsonb(x) from weeks x where week_start = w)); end $function$;

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$ declare want text := nullif(new.raw_user_meta_data->>'staff_name',''); begin if want is not null and (not exists(select 1 from staff where name = want and active) or exists(select 1 from profiles where staff_name = want)) then want := null; end if; insert into profiles(id, phone, staff_name, role, status) values (new.id, new.raw_user_meta_data->>'phone', want, case when lower(new.email) = 'guypoor@gmail.com' then 'admin' else 'employee' end, case when lower(new.email) = 'guypoor@gmail.com' then 'active' else 'pending' end); return new; end $function$;

CREATE OR REPLACE FUNCTION public.il_today() RETURNS date LANGUAGE sql STABLE AS $function$ select (now() at time zone 'Asia/Jerusalem')::date $function$;

CREATE OR REPLACE FUNCTION public.is_active() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ select exists(select 1 from profiles where id = auth.uid() and status = 'active') $function$;

CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ select exists(select 1 from profiles where id = auth.uid() and role = 'admin' and status = 'active') $function$;

CREATE OR REPLACE FUNCTION public.my_staff() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ select staff_name from profiles where id = auth.uid() and status = 'active' $function$;

CREATE OR REPLACE FUNCTION public.protect_profile() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$ begin if auth.uid() is null or public.is_admin() then return new; end if; if new.id <> old.id or new.role is distinct from old.role or new.status is distinct from old.status or new.staff_name is distinct from old.staff_name or new.phone is distinct from old.phone or new.clock_mode is distinct from old.clock_mode or new.clock_mode_date is distinct from old.clock_mode_date then raise exception 'not allowed'; end if; if new.avatar is not null and (length(new.avatar) > 60000 or new.avatar !~ '^data:image/jpeg;base64,[A-Za-z0-9+/]+=*$') then raise exception 'bad avatar'; end if; return new; end $function$;

CREATE OR REPLACE FUNCTION public.punch(p_action text, p_lat double precision, p_lon double precision, p_acc double precision, p_device text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$ declare n text := public.my_staff(); st jsonb; mode text; d int; s jsonb; maxd int; maxacc int; l record; hrs numeric; t text; begin if n is null then return jsonb_build_object('ok', false, 'error', 'החשבון לא פעיל. פנה/י לגיא.'); end if; if p_action not in ('in','out') then return jsonb_build_object('ok', false, 'error', 'פעולה לא מוכרת'); end if; perform pg_advisory_xact_lock(hashtext('punch:' || n)); st := public.clock_state_for(n); mode := st->>'mode'; if mode = 'off' then return jsonb_build_object('ok', false, 'code', 'off', 'error', 'השעון כבוי עבורך כרגע. לפרטים פנה/י לגיא.', 'state', st); end if; s := (select v from settings where k = 'store'); maxd := coalesce((s->>'max_dist')::int, 120); maxacc := coalesce((s->>'max_acc')::int, 150); if p_lat is not null and p_lon is not null then d := public.dist_m((s->>'lat')::float8, (s->>'lon')::float8, p_lat, p_lon); end if; if mode <> 'remote' then if d is null then return jsonb_build_object('ok', false, 'code', 'noloc', 'error', 'אין מיקום. אשר/י גישה למיקום ונסה/י שוב.'); end if; if p_acc is not null and p_acc > maxacc then return jsonb_build_object('ok', false, 'code', 'acc', 'dist', d, 'error', 'המיקום לא מדויק מספיק (±' || round(p_acc) || ' מ׳). צא/י רגע לפתח החנות או הפעל/י Wi-Fi ונסה/י שוב.'); end if; if d > maxd then return jsonb_build_object('ok', false, 'code', 'far', 'dist', d, 'error', 'נראה שאת/ה לא בחנות (' || d || ' מ׳ מהחנות). אפשר להחתים רק מתוך החנות.'); end if; end if; if p_action = 'in' and (st->>'in')::boolean then return jsonb_build_object('ok', false, 'code', 'already', 'state', st, 'error', 'כבר נכנסת ב-' || to_char((st->>'since')::timestamptz at time zone 'Asia/Jerusalem', 'HH24:MI') || '.'); end if; if p_action = 'out' and not (st->>'in')::boolean then return jsonb_build_object('ok', false, 'code', 'notin', 'state', st, 'error', 'אין כניסה פתוחה להחתמת יציאה.'); end if; insert into punches(staff_name, action, dist, acc, remote, device) values (n, p_action, d, round(p_acc)::int, mode = 'remote', left(coalesce(p_device,''), 40)); t := to_char(now() at time zone 'Asia/Jerusalem', 'HH24:MI'); if p_action = 'out' then hrs := round(extract(epoch from now() - (st->>'since')::timestamptz) / 3600.0, 2); return jsonb_build_object('ok', true, 'in', false, 'since', null, 'hours', hrs, 'msg', 'יציאה נרשמה ב-' || t || '. עבדת ' || hrs || ' שעות.'); end if; return jsonb_build_object('ok', true, 'in', true, 'since', now(), 'msg', 'כניסה נרשמה ב-' || t || '.'); end $function$;

CREATE OR REPLACE FUNCTION public.reg_names() RETURNS TABLE(name text, taken boolean) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ select s.name, exists(select 1 from profiles p where p.staff_name = s.name) from staff s where s.active order by s.sort, s.name $function$;

CREATE OR REPLACE FUNCTION public.target_week() RETURNS date LANGUAGE sql STABLE AS $function$ select public.il_today() + (7 - extract(dow from public.il_today())::int) $function$;

CREATE OR REPLACE FUNCTION public.team() RETURNS TABLE(name text, color text, fg text, avatar text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$ select s.name, s.color, s.fg, (select p.avatar from profiles p where p.staff_name = s.name limit 1) from staff s where s.active and public.is_active() order by s.sort, s.name $function$;

create or replace view public.sessions with (security_invoker=true) as SELECT i.staff_name, i.at AS t_in, o.at AS t_out, CASE WHEN o.at IS NOT NULL THEN round(EXTRACT(epoch FROM o.at - i.at) / 3600.0, 2) ELSE NULL::numeric END AS hours, i.remote, (i.at AT TIME ZONE 'Asia/Jerusalem'::text)::date AS day, CASE WHEN o.at IS NULL AND (now() - i.at) >= '16:00:00'::interval THEN 'חסרה יציאה'::text ELSE NULL::text END AS flag FROM punches i LEFT JOIN LATERAL ( SELECT o_1.at FROM punches o_1 WHERE o_1.staff_name = i.staff_name AND o_1.action = 'out'::text AND o_1.at > i.at AND NOT (EXISTS ( SELECT 1 FROM punches x WHERE x.staff_name = i.staff_name AND x.action = 'in'::text AND x.at > i.at AND x.at < o_1.at)) ORDER BY o_1.at LIMIT 1) o ON true WHERE i.action = 'in'::text;

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE TRIGGER protect_profile BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION protect_profile();

alter table public.availability enable row level security;

alter table public.profiles enable row level security;

alter table public.punches enable row level security;

alter table public.settings enable row level security;

alter table public.staff enable row level security;

alter table public.weeks enable row level security;

create policy av_del on public.availability as PERMISSIVE for DELETE to authenticated using (is_admin());

create policy av_ins on public.availability as PERMISSIVE for INSERT to authenticated with check ((is_admin() OR ((staff_name = my_staff()) AND (week_start >= target_week()))));

create policy av_read on public.availability as PERMISSIVE for SELECT to authenticated using ((is_admin() OR (staff_name = my_staff())));

create policy av_upd on public.availability as PERMISSIVE for UPDATE to authenticated using ((is_admin() OR ((staff_name = my_staff()) AND (week_start >= target_week())))) with check ((is_admin() OR ((staff_name = my_staff()) AND (week_start >= target_week()))));

create policy prof_del on public.profiles as PERMISSIVE for DELETE to authenticated using (is_admin());

create policy prof_read on public.profiles as PERMISSIVE for SELECT to authenticated using (((id = auth.uid()) OR is_admin()));

create policy prof_upd on public.profiles as PERMISSIVE for UPDATE to authenticated using (((id = auth.uid()) OR is_admin())) with check (((id = auth.uid()) OR is_admin()));

create policy p_admin on public.punches as PERMISSIVE for ALL to authenticated using (is_admin()) with check (is_admin());

create policy p_read on public.punches as PERMISSIVE for SELECT to authenticated using ((is_admin() OR (staff_name = my_staff())));

create policy settings_admin on public.settings as PERMISSIVE for ALL to authenticated using (is_admin()) with check (is_admin());

create policy staff_admin on public.staff as PERMISSIVE for ALL to authenticated using (is_admin()) with check (is_admin());

create policy staff_read on public.staff as PERMISSIVE for SELECT to authenticated using (is_active());

create policy weeks_admin on public.weeks as PERMISSIVE for ALL to authenticated using (is_admin()) with check (is_admin());

create policy weeks_read on public.weeks as PERMISSIVE for SELECT to authenticated using ((is_admin() OR (is_active() AND published)));

alter sequence public.punches_id_seq owned by public.punches.id;

-- Grants (Supabase defaults, as found in the live DB). Access is enforced by RLS above:
-- every policy targets "authenticated" only, so "anon" sees no rows.
grant all on public.availability, public.profiles, public.punches, public.sessions, public.settings, public.staff, public.weeks to anon, authenticated;
grant usage on sequence public.punches_id_seq to anon, authenticated;
-- All public functions: EXECUTE for PUBLIC, anon, authenticated, service_role (Supabase default).
-- Each SECURITY DEFINER function checks permissions itself: is_admin()/my_staff() via auth.uid(), ha_* via ha_ok(p_token).
