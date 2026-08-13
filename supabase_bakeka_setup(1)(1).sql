-- =========================================================
-- XA3 / BakekaSocialPROJECTS — Supabase setup
-- =========================================================
-- PRIMA DI USARE IL SITO:
-- 1) Supabase Dashboard > Authentication > Providers
--    abilita "Anonymous Sign-Ins".
-- 2) Esegui questo file nel Supabase SQL Editor.
-- 3) In Project Settings / API copia nel file HTML SOLO:
--    - Project URL
--    - Publishable key (oppure legacy anon key)
-- NON inserire mai Secret key o service_role key nell'HTML.

create extension if not exists pgcrypto;

create table if not exists public.xa3_project_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  project_name text not null check (char_length(project_name) between 1 and 60),
  symbol text not null check (char_length(symbol) between 1 and 18),
  image text,
  story text not null check (char_length(story) between 1 and 900),
  utility text not null check (char_length(utility) between 1 and 900),
  wallet text not null check (char_length(wallet) between 1 and 80),
  created_at timestamptz not null default now()
);

create index if not exists xa3_project_posts_created_at_idx
  on public.xa3_project_posts (created_at desc);

create index if not exists xa3_project_posts_owner_id_idx
  on public.xa3_project_posts (owner_id);

alter table public.xa3_project_posts enable row level security;

-- Accesso alla tabella dalla Data API.
grant usage on schema public to anon, authenticated;
grant select on public.xa3_project_posts to anon, authenticated;
grant insert, delete on public.xa3_project_posts to authenticated;

-- Ricrea policy in modo idempotente.
drop policy if exists "xa3 board public read" on public.xa3_project_posts;
drop policy if exists "xa3 board insert own session" on public.xa3_project_posts;
drop policy if exists "xa3 board delete own session" on public.xa3_project_posts;

-- Tutti possono leggere il feed, anche senza login visibile.
create policy "xa3 board public read"
on public.xa3_project_posts
for select
to anon, authenticated
using (true);

-- La scrittura richiede una sessione Supabase autenticata.
-- Il sito la crea anonimamente SOLO dopo che Xaman è collegato.
create policy "xa3 board insert own session"
on public.xa3_project_posts
for insert
to authenticated
with check ((select auth.uid()) = owner_id);

-- Solo la stessa sessione che ha creato il post può cancellarlo.
create policy "xa3 board delete own session"
on public.xa3_project_posts
for delete
to authenticated
using ((select auth.uid()) = owner_id);

-- Abilita gli eventi INSERT / DELETE / UPDATE per il feed Realtime.
do $$
begin
  alter publication supabase_realtime add table public.xa3_project_posts;
exception
  when duplicate_object then null;
end $$;
