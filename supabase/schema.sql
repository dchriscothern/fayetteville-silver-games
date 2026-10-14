-- Fayetteville Girls Silver Academy — database schema, RLS, and grants
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Needs your own authenticated session in the SQL Editor; no service-role key required.

create extension if not exists pgcrypto;

-- ===== ADMIN ROLE =====
-- Deliberately has NO grants to anon/authenticated below, so it is reachable only
-- from the SQL Editor (your own session), never from the public API.
create table public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- ===== PLAYERS (team-assigned codes, never children's names) =====
create table public.players (
  id uuid primary key default gen_random_uuid(),
  player_code text unique not null,       -- e.g. 'SILVER-07'
  team text not null default 'Fayetteville Girls Silver',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ===== PARENT -> PLAYER MAPPING =====
-- The security-critical table: a player_code alone is never enough to read or
-- write a player's data, only a matching row here (or admin) grants access.
-- Rows are created by the coach (admin) in the SQL Editor or a future admin
-- tool, never by a parent picking their own code client-side.
create table public.player_guardians (
  id uuid primary key default gen_random_uuid(),
  parent_user_id uuid not null references auth.users(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (parent_user_id, player_id)
);

-- ===== GAME RESULTS =====
create table public.game_results (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  game_id text not null,              -- 'advantage_hunter', 'rotation_rescue', ...
  mode text,                          -- 'practice' | 'timed'
  tally jsonb not null,               -- the game's own end-of-session tally object
  scenario_count int,
  completed_at timestamptz not null default now()
);

-- ===== PRIVATE COACH FEEDBACK =====
-- Invisible to parents until you set published = true; absent, not empty.
create table public.coach_feedback (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  body text not null,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ===== helper: does the signed-in user have access to this player? =====
create or replace function public.can_access_player(p_player_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.is_admin() or exists (
    select 1 from public.player_guardians
    where player_id = p_player_id and parent_user_id = auth.uid()
  );
$$;

-- ===== ROW LEVEL SECURITY =====
alter table public.players enable row level security;
alter table public.player_guardians enable row level security;
alter table public.game_results enable row level security;
alter table public.coach_feedback enable row level security;

create policy players_select on public.players
  for select using (public.can_access_player(id));
create policy players_admin_write on public.players
  for all using (public.is_admin()) with check (public.is_admin());

create policy guardians_select on public.player_guardians
  for select using (public.is_admin() or parent_user_id = auth.uid());
create policy guardians_admin_write on public.player_guardians
  for all using (public.is_admin()) with check (public.is_admin());

create policy results_select on public.game_results
  for select using (public.can_access_player(player_id));
create policy results_insert on public.game_results
  for insert with check (public.can_access_player(player_id));
create policy results_admin_write on public.game_results
  for update using (public.is_admin()) with check (public.is_admin());
create policy results_admin_delete on public.game_results
  for delete using (public.is_admin());

create policy feedback_select on public.coach_feedback
  for select using (
    public.is_admin()
    or (published and public.can_access_player(player_id))
  );
create policy feedback_admin_write on public.coach_feedback
  for all using (public.is_admin()) with check (public.is_admin());

-- ===== EXPLICIT GRANTS =====
-- RLS only filters rows that a query is allowed to see; Postgres still checks
-- table-level privileges first. Without these grants every request 403s even
-- when the policies above are correct.
revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;

grant select, insert, update, delete on public.players to authenticated;          -- narrowed by RLS to admin
grant select, insert, update, delete on public.player_guardians to authenticated; -- narrowed by RLS to admin
grant select, insert, update, delete on public.game_results to authenticated;     -- insert/select for a player's own guardian, update/delete narrowed to admin
grant select, insert, update, delete on public.coach_feedback to authenticated;   -- narrowed by RLS to admin

-- ===== ONE-TIME BOOTSTRAP (after this script runs) =====
-- 1. Sign in once on the site with your own email via the magic link, so
--    auth.users has a row for you. Then run, filling in your real email:
--
--    insert into public.admins (user_id)
--    select id from auth.users where email = 'YOUR_EMAIL_HERE';
--
-- 2. Add each player and her guardian(s), e.g.:
--
--    insert into public.players (player_code) values ('SILVER-01'), ('SILVER-02');
--
--    insert into public.player_guardians (parent_user_id, player_id)
--    select u.id, p.id
--    from auth.users u, public.players p
--    where u.email = 'parent_email_here' and p.player_code = 'SILVER-01';
