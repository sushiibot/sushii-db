-- The 'admin' role (used by PostGraphile to represent sushii services) may
-- access the public, app_public and app_hidden schemas (but _NOT_ the
-- app_private schema).
grant usage on schema public, app_public, app_hidden to :DATABASE_ADMIN;

-- We want the `admin` role to be able to insert rows (`serial` data type
-- creates sequences, so we need to grant access to that).
alter default privileges in schema public, app_public, app_hidden
  grant usage, select on sequences to :DATABASE_ADMIN;

-- And the `admin` role should be able to call functions too.
alter default privileges in schema public, app_public, app_hidden
  grant execute on functions to :DATABASE_ADMIN;

alter default privileges in schema public, app_public, app_hidden
  grant select, insert, update, delete
    on tables to :DATABASE_ADMIN;

grant select, insert, update on all tables in
  schema app_public to :DATABASE_ADMIN;

--- Add permissions for admin role to access existing app_public tables

alter table app_public.guild_configs enable row level security;
drop policy if exists admin_access on app_public.guild_configs;
create policy admin_access on app_public.guild_configs
  for all to :DATABASE_ADMIN using (true);

alter table app_public.mod_logs enable row level security;
drop policy if exists admin_access on app_public.mod_logs;
create policy admin_access on app_public.mod_logs
  for all to :DATABASE_ADMIN using (true);

alter table app_public.mutes enable row level security;
drop policy if exists admin_access on app_public.mutes;
create policy admin_access on app_public.mutes
  for all to :DATABASE_ADMIN using (true);

drop policy if exists admin_access on app_public.user_levels;
create policy admin_access on app_public.user_levels
  for all to :DATABASE_ADMIN using (true);

drop policy if exists admin_access on app_public.users;
create policy admin_access on app_public.users
  for all to :DATABASE_ADMIN using (true);

drop policy if exists admin_access on app_public.tags;
create policy admin_access on app_public.tags
  for all to :DATABASE_ADMIN using (true);

drop policy if exists admin_access on app_public.messages;
create policy admin_access on app_public.messages
  for all to :DATABASE_ADMIN using (true);

drop policy if exists admin_access on app_public.notifications;
create policy admin_access on app_public.notifications
  for all to :DATABASE_ADMIN using (true);

drop policy if exists admin_access on app_public.reminders;
create policy admin_access on app_public.reminders
  for all to :DATABASE_ADMIN using (true);

---

drop table if exists app_public.role_menus cascade;
create table app_public.role_menus (
  message_id bigint not null primary key,
  guild_id   bigint not null,
  channel_id bigint not null,
  editor_id  bigint
);

create index rolemenu_guildid_idx on app_public.role_menus(guild_id);

alter table app_public.role_menus enable row level security;

-- does not include policy for visitor role
drop policy if exists admin_access on app_public.role_menus;
create policy admin_access on app_public.role_menus
  for all to :DATABASE_ADMIN using (true);


---
