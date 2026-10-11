-- הרצה ב-Supabase SQL Editor (קריאה בלבד): מחזיר תא אחד (ddl) עם כל הסכמה. להעתיק את התא ולשמור כ-team/supabase/schema.sql
-- read-only schema dump (public + triggers on auth.users)
with
tbl as (
  select 10 ord, c.relname nm, 'create table if not exists public.'||quote_ident(c.relname)||E' (\n  '||
    string_agg(quote_ident(a.attname)||' '||format_type(a.atttypid,a.atttypmod)||
      coalesce(' default '||pg_get_expr(d.adbin,d.adrelid),'')||case when a.attnotnull then ' not null' else '' end, E',\n  ' order by a.attnum)||E'\n);' s
  from pg_class c join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
  left join pg_attrdef d on d.adrelid=c.oid and d.adnum=a.attnum
  where c.relkind='r' group by c.relname),
con as (
  select 20 ord, conrelid::regclass::text||conname nm, 'alter table '||conrelid::regclass::text||' add constraint '||quote_ident(conname)||' '||pg_get_constraintdef(oid)||';' s
  from pg_constraint where connamespace='public'::regnamespace and contype in ('p','u','f','c')),
idx as (
  select 25 ord, indexrelid::regclass::text nm, pg_get_indexdef(indexrelid)||';' s from pg_index i
  join pg_class c on c.oid=i.indrelid join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
  where not i.indisprimary and not exists(select 1 from pg_constraint k where k.conindid=i.indexrelid)),
fn as (
  select 30 ord, p.proname||p.oid nm, pg_get_functiondef(p.oid)||';' s
  from pg_proc p where p.pronamespace='public'::regnamespace and p.prokind='f'),
vw as (
  select 40 ord, c.relname nm, 'create or replace view public.'||quote_ident(c.relname)||coalesce(' with ('||array_to_string(c.reloptions,', ')||')','')||E' as\n'||pg_get_viewdef(c.oid,true) s
  from pg_class c where c.relnamespace='public'::regnamespace and c.relkind='v'),
trg as (
  select 50 ord, t.tgname nm, pg_get_triggerdef(t.oid,true)||';' s
  from pg_trigger t join pg_class c on c.oid=t.tgrelid
  where not t.tgisinternal and (c.relnamespace='public'::regnamespace or (c.relnamespace='auth'::regnamespace and c.relname='users'))),
rls as (
  select 60 ord, c.relname nm, 'alter table public.'||quote_ident(c.relname)||' enable row level security;' s
  from pg_class c where c.relnamespace='public'::regnamespace and c.relkind='r' and c.relrowsecurity),
pol as (
  select 70 ord, tablename||policyname nm, 'create policy '||quote_ident(policyname)||' on public.'||quote_ident(tablename)||' as '||permissive||' for '||cmd||' to '||array_to_string(roles,', ')||
    coalesce(' using ('||qual||')','')||coalesce(' with check ('||with_check||')','')||';' s
  from pg_policies where schemaname='public'),
tg as (
  select 80 ord, table_name||grantee||privilege_type nm, 'grant '||privilege_type||' on public.'||quote_ident(table_name)||' to '||grantee||';' s
  from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated')),
fg as (
  select 90 ord, p.proname||p.oid nm,
    'function public.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||') security '||case when p.prosecdef then 'definer' else 'invoker' end||
    ' | acl: '||coalesce(array_to_string(p.proacl,' '),'(default: PUBLIC execute)') s
  from pg_proc p where p.pronamespace='public'::regnamespace and p.prokind='f'),
allx as (select * from tbl union all select * from con union all select * from idx union all select * from fn union all select * from vw
  union all select * from trg union all select * from rls union all select * from pol union all select * from tg union all select * from fg)
select string_agg(s, E'\n\n' order by ord, nm) as ddl from allx;
