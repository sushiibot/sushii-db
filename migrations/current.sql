-- ban pools

drop type if exists app_public.ban_pool_visibility    cascade;
drop type if exists app_public.ban_pool_permission    cascade;
drop type if exists app_public.ban_pool_add_mode      cascade;
drop type if exists app_public.ban_pool_follower_mode cascade;

drop table if exists app_public.ban_pools        cascade;
drop table if exists app_public.ban_pool_members cascade;
drop table if exists app_public.ban_pool_entries cascade;

create type app_public.ban_pool_visibility as enum (
  'public',
  'private'
);

create type app_public.ban_pool_permission as enum (
  'view',
  'edit'
);

create type app_public.ban_pool_add_mode as enum (
  'all_bans',
  'manual'
);

create type app_public.ban_pool_follower_mode as enum (
  'ban',
  'require_confirmation'
);

create table app_public.ban_pools (
  guild_id  bigint not null,
  pool_name text   not null,

  add_mode   app_public.ban_pool_add_mode       not null default 'all_bans',
  visibility app_public.ban_pool_visibility not null default 'private',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (guild_id, pool_name)
);

-- Other servers can join ban pools by invitation or public pools
create table app_public.ban_pool_members (
  owner_guild_id  bigint not null,
  pool_name       text   not null,
  member_guild_id bigint not null,

  -- Invited guilds can view the pool, but not edit it.
  -- Can be changed to 'edit' by pool owner, which lets them add bans.
  permission    app_public.ban_pool_permission    not null default 'view',
  follower_mode app_public.ban_pool_follower_mode not null default 'ban',

  primary key (owner_guild_id, pool_name, member_guild_id)
);

create table app_public.ban_pool_entries (
  guild_id  bigint not null,
  pool_name text   not null,

  -- banned user
  user_id   bigint not null,

  primary key (owner_guild_id, pool_name, member_guild_id)
);
