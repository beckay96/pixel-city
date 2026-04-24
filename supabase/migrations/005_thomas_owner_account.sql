-- Optional: create the reserved owner account (username thomas) with password "francis"
-- if it does not exist. Run in Supabase SQL Editor if you have not already created thomas
-- via migration 003 notes.
-- If thomas already exists with a different password, run instead:
--   update public.users set password_hash = crypt('francis', gen_salt('bf')) where username = 'thomas';

insert into public.users (username, password_hash)
select 'thomas', crypt('francis', gen_salt('bf'))
where not exists (select 1 from public.users where username = 'thomas');
