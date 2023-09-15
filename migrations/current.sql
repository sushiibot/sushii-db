-- ban pools

drop type if exists app_public.ban_pool_visibility         cascade;
drop type if exists app_public.ban_pool_permission         cascade;
drop type if exists app_public.ban_pool_add_mode           cascade;
drop type if exists app_public.ban_pool_remove_mode        cascade;
drop type if exists app_public.ban_pool_add_action    cascade;
drop type if exists app_public.ban_pool_remove_action cascade;

drop table if exists app_public.ban_pools        cascade;
drop table if exists app_public.ban_pool_members cascade;
drop table if exists app_public.ban_pool_entries cascade;

create type app_public.ban_pool_visibility as enum (
  'public',
  'private'
);

-- Whether or not a guild can view or edit another guild's ban pool.
-- Blocked guilds can't view or edit the pool.
create type app_public.ban_pool_permission as enum (
  'view',
  'edit',
  'block'
);

-- When users are added to ban pools for owners/editors:
-- 1. Auto add for all banned users
-- 2. Manually add users with command or mod log
create type app_public.ban_pool_add_mode as enum (
  'all_bans',
  'manual'
);

-- When to remove users from pool:
-- 1. Auto remove for all unbanned users in current server.
-- 2. Only manually removed from pool with command.
create type app_public.ban_pool_remove_mode as enum (
  'all_unbans',
  'manual'
);

-- What to do when a user is added to a pool by another guild, either as follower or owner:
-- 1. Ban users automatically when a user is added to a pool.
-- 2. Send a prompt for confirmation when a user is added to a pool.
create type app_public.ban_pool_add_action as enum (
  'ban',
  'require_confirmation'
);

-- What to do when a user is removed from a pool by another guild:
-- 1. Unban users automatically when a user is removed from a pool.
-- 2. Send a prompt for confirmation when a user is removed from a pool.
create type app_public.ban_pool_remove_action as enum (
  'unban',
  'require_confirmation'
);

create table app_public.ban_pools (
  guild_id    bigint not null,
  pool_name   text   not null,
  description text,

  -- Owner settings
  add_mode    app_public.ban_pool_add_mode    not null default 'all_bans',
  remove_mode app_public.ban_pool_remove_mode not null default 'all_unbans',

  -- Actions for shared pools, when added/removed by editors
  add_action    app_public.ban_pool_add_action    not null default 'ban',
  remove_action app_public.ban_pool_remove_action not null default 'unban',

  -- Follower visibility
  visibility  app_public.ban_pool_visibility  not null default 'private',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (guild_id, pool_name)
);

-- Other servers can join ban pools by invitation or public pools
create table app_public.ban_pool_members (
  owner_guild_id  bigint not null,
  pool_name       text   not null,
  member_guild_id bigint not null,

  -- Whether or not the invitation has been accepted. Inviting creates a row.
  -- Only applicable for private pools. Inviting guilds is also only applicable
  -- for private pools.
  accepted        boolean not null default false,

  -- Invited guilds can view the pool, but not edit it.
  -- Can be changed to 'edit' by pool owner, which lets them add bans.
  permission  app_public.ban_pool_permission  not null default 'view',

  -- Only for pool members with edit permissions.
  add_mode    app_public.ban_pool_add_mode    not null default 'all_bans',
  remove_mode app_public.ban_pool_remove_mode not null default 'all_unbans',

  -- For all pool members with edit/view permissions.
  add_action    app_public.ban_pool_add_action    not null default 'ban',
  remove_action app_public.ban_pool_remove_action not null default 'unban',

  primary key (owner_guild_id, pool_name, member_guild_id)
);

create table app_public.ban_pool_entries (
  owner_guild_id bigint not null,
  pool_name      text   not null,

  -- Guild the entry was added from, could be owner or editor
  source_guild_id bigint not null,

  -- Banned user
  user_id bigint not null,
  -- Additional reason for ban pool, does not use mod log reason unless imported ?
  reason  text,

  primary key (owner_guild_id, pool_name, user_id)
);
