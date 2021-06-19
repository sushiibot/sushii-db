drop table if exists app_public.guild_bans cascade;
create table app_public.guild_bans (
    guild_id   bigint    not null,
    user_id    bigint    not null,
    primary key (guild_id, user_id)
);

-- Lookups via single user_id
create index on app_public.guild_bans(user_id);

alter table app_public.guild_bans enable row level security;
drop policy if exists select_managed on app_public.guild_bans;
create policy select_managed on app_public.guild_bans
  for select using (guild_id in (select app_public.current_user_managed_guild_ids()));

grant select on app_public.guild_bans to :DATABASE_VISITOR;

alter table app_public.guild_configs
  drop column if exists data;

alter table app_public.guild_configs
  add column data jsonb not null default '{}';

