-- Enter migration here
---

drop table if exists app_public.role_menus cascade;
create table app_public.role_menus (
  message_id bigint not null unique,
  guild_id   bigint not null,
  channel_id bigint not null,
  editor_id  bigint,

  primary key (channel_id, editor_id)
);

create index rolemenu_guildid_idx on app_public.role_menus(guild_id);

alter table app_public.role_menus enable row level security;

-- does not include policy for visitor role
drop policy if exists admin_access on app_public.role_menus;
create policy admin_access on app_public.role_menus
  for all to :DATABASE_ADMIN using (true);
  