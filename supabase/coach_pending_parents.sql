-- Fayetteville Girls Silver Academy: pending opt-in parent sign-ins
-- ONE-TIME MIGRATION. Run in Supabase SQL Editor.
-- Lists only email-confirmed users who have no player link and are not coaches.
-- Does not create users, assign player codes, or invite anyone.
create or replace function public.coach_pending_parents()
returns table(parent_email text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Coach access required';
  end if;
  return query
    select u.email::text
      from auth.users u
      where u.email_confirmed_at is not null
        and u.email is not null
        and not exists (
          select 1 from public.player_guardians pg
          where pg.parent_user_id = u.id
        )
        and not exists (
          select 1 from public.admins a
          where a.user_id = u.id
        )
      order by u.created_at desc;
end;
$$;
revoke all on function public.coach_pending_parents() from public, anon;
grant execute on function public.coach_pending_parents() to authenticated;
