-- Run this once in the Supabase SQL Editor, after schema.sql.
-- Lets the signed-in web app ask "is this user the coach" (true/false)
-- without ever exposing the admins table itself to the client.
grant execute on function public.is_admin() to authenticated;
