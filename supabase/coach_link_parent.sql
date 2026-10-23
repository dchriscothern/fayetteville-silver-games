-- One-time migration for Fayetteville Girls Silver Coach Area: Link Parent.
-- Paste into Supabase SQL Editor and Run once.
-- Does NOT create or invite parent accounts. Only links an existing parent
-- auth.users record after that parent has opted in and signed in.

create or replace function public.coach_link_parent(
  p_email text,
  p_player_code text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent_id uuid;
  v_player_id uuid;
  v_rows integer;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Coach access required';
  end if;

  if p_email is null or length(trim(p_email)) = 0 then
    raise exception 'Parent email is required';
  end if;

  select id into v_parent_id
  from auth.users
  where lower(email) = lower(trim(p_email))
    and email_confirmed_at is not null
  limit 1;

  if v_parent_id is null then
    raise exception 'No confirmed account found for this email. Ask the parent to sign in through My Progress first.';
  end if;

  select id into v_player_id
  from public.players
  where player_code = upper(trim(p_player_code))
    and active = true
  limit 1;

  if v_player_id is null then
    raise exception 'Player code not found or inactive';
  end if;

  insert into public.player_guardians (parent_user_id, player_id)
  values (v_parent_id, v_player_id)
  on conflict (parent_user_id, player_id) do nothing;

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return 'already_linked';
  end if;
  return 'linked';
end;
$$;

revoke all on function public.coach_link_parent(text,text) from public, anon;
grant execute on function public.coach_link_parent(text,text) to authenticated;
