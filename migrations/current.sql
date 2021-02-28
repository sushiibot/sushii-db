-- postgraphile auth stuff
-- and other stuff for reworked sushii-web with postgraphile

-- enable existing public stuff to be viewed
-- we don't directly use user_levels table, use view below to calculate levels stuff
-- alter table app_public.user_levels enable row level security;

-- add views and stuff for calculating user XP for leaderboards

-- gets the user's current level from **total** xp
-- https://gamedev.stackexchange.com/questions/13638/algorithm-for-dynamically-calculating-a-level-based-on-experience-points#comment124885_13639
-- Equations for the linearly rising level gap. level = (sqrt(100(2experience+25))+50)/100
drop function if exists app_hidden.level_from_xp(xp bigint) cascade;
create function app_hidden.level_from_xp(xp bigint) returns bigint as $$
  select floor((sqrt(100 * (2 * xp + 25)) + 50) / 100)::bigint;
$$ language sql stable;

-- experience =(level^2+level)/2*100-(level*100)
drop function if exists app_hidden.xp_from_level(level bigint) cascade;
create function app_hidden.xp_from_level(level bigint) returns bigint as $$
  select floor((pow(level, 2) + level) / 2 * 100 - (level * 100))::bigint;
$$ language sql stable;

-- how much xp a user has progressed in a single level
-- ie if they are level 2 and they have 150 xp, level 1 required 100xp
-- this will return 50xp
drop materialized view if exists app_public.user_levels_global cascade;
create materialized view app_public.user_levels_global
    as select t.user_id,
              avatar_url,
              name,
              discriminator,
              t.xp,
              current_level,
              next_level_xp_required,
              next_level_xp_progress
         from (select user_id,
                      sum(msg_all_time) as xp
                 from app_public.user_levels
             group by user_id) t
             -- join the cached users to get username/avatar/discrim
             left join app_public.cached_users
                    on user_id = id,
             -- lateral joins to reuse calculations
             lateral (select app_hidden.level_from_xp(xp::bigint)
                             as current_level
                     ) c,
             lateral (select (app_hidden.xp_from_level(current_level + 1) - xp)
                             as next_level_xp_required
                     ) r,
             lateral (select (xp - app_hidden.xp_from_level(current_level))
                             as next_level_xp_progress
                     ) p
     order by xp desc,
              user_id desc
              with data;

-- required to refresh materialized view concurrently
create unique index on app_public.user_levels_global(user_id);

comment on materialized view app_public.user_levels_global is
  E'Global leaderboard for user levels. All XP in each guild is aggregated for each user.';
grant select on app_public.user_levels_global to :DATABASE_VISITOR;

drop function if exists app_public.user_levels_global_cached_user(
  user_level app_public.user_levels_global
) cascade;

create function app_public.user_levels_global_cached_user(
  user_level app_public.user_levels_global
) returns app_public.cached_users as $$
  select *
    from app_public.cached_users
   where id = user_level.user_id;
$$ language sql stable;

grant execute on function app_public.user_levels_global_cached_user(
  user_level app_public.user_levels_global
) to :DATABASE_VISITOR;

/**********/


-- now auth stuff

/**********/
drop table if exists app_private.sessions cascade;
create table app_private.sessions (
  uuid        uuid        not null default gen_random_uuid() primary key,
  -- discord user id
  user_id     bigint      not null,
  -- You could add access restriction columns here if you want, e.g. for OAuth scopes.
  created_at  timestamptz not null default now(),
  last_active timestamptz not null default now()
);
alter table app_private.sessions enable row level security;

/**********/

drop function if exists app_public.current_session_id() cascade;
create function app_public.current_session_id() returns uuid as $$
  select nullif(pg_catalog.current_setting('jwt.claims.session_id', true), '')::uuid;
$$ language sql stable;
comment on function app_public.current_session_id() is
  E'Handy method to get the current session ID.';
-- We've put this in public, but omitted it, because it's often useful for debugging auth issues.

/**********/

drop function if exists app_public.current_user_id() cascade;
create function app_public.current_user_id() returns bigint as $$
  select user_id
    from app_private.sessions
   where uuid = app_public.current_session_id();
$$ language sql stable security definer set search_path to pg_catalog, public, pg_temp;
comment on function app_public.current_user_id() is
  E'Handy method to get the current user ID for use in RLS policies, etc; in GraphQL, use `currentUser{id}` instead.';

/**********/

drop function if exists app_private.tg__timestamps() cascade;
create function app_private.tg__timestamps() returns trigger as $$
begin
  NEW.created_at = (case when TG_OP = 'INSERT' then NOW() else OLD.created_at end);
  NEW.updated_at = (case when TG_OP = 'UPDATE' and OLD.updated_at >= NOW() then OLD.updated_at + interval '1 millisecond' else NOW() end);
  return NEW;
end;
$$ language plpgsql volatile set search_path to pg_catalog, public, pg_temp;
comment on function app_private.tg__timestamps() is
  E'This trigger should be called on all tables with created_at, updated_at - it ensures that they cannot be manipulated and that updated_at will always be larger than the previous updated_at.';

/**********/

-- users that logged into web ui
-- this is app_public.users and app_public.user_authentications from the graphile/starter merged
-- since we only care about a single oauth discord login we don't need an extra table for multiple auths
drop table if exists app_public.web_users cascade;
create table app_public.web_users (
    -- discord user ID
    id            bigint      primary key,
    -- discord username/discrim
    username      text        not null,
    discriminator int         not null,
    -- avatar hash
    avatar        text,
    is_admin      boolean     not null default false,
    -- oauth info
    details jsonb not null default '{}'::jsonb,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);
alter table app_public.web_users enable row level security;

-- add foriegn key and index to sessions
alter table app_private.sessions
add constraint sessions_user_id_fkey
   foreign key ("user_id")
    references app_public.web_users on delete cascade;

create index on app_private.sessions (user_id);

-- rls stuff
create policy select_self on app_public.web_users for select using (id = app_public.current_user_id());
create policy update_self on app_public.web_users for update using (id = app_public.current_user_id());
grant select on app_public.web_users to :DATABASE_VISITOR;
-- no update is granted since all attributes are to follow their discord user, do not want users to modify
-- grant update(username, name, avatar_url) on app_public.web_users to :DATABASE_VISITOR;

comment on table app_public.web_users is
  E'A user who can log in to the application.';
comment on column app_public.web_users.id is
  E'Unique identifier for the user. This should match their Discord ID.';
comment on column app_public.web_users.username is
  E'Discord username of the user.';
comment on column app_public.web_users.discriminator is
  E'Discord disciminator of the user.';
comment on column app_public.web_users.avatar is
  E'Discord avatar hash. Null if user does not have one.';
comment on column app_public.web_users.is_admin is
  E'If true, the user has elevated privileges.';
comment on column app_public.web_users.details is
  E'Additional profile details extracted from Discord oauth';
comment on column app_public.web_users.created_at is
  E'First registered on the application. Is not when a user created their Discord account.';

-- Update created_at, updated_at
create trigger _100_timestamps
  before insert or update on app_public.web_users
  for each row
  execute procedure app_private.tg__timestamps();

/**********/

drop table if exists app_public.web_guilds cascade;
create table app_public.web_guilds (
    id         bigint primary key,
    -- nullable since sushii might not be in web_guilds
    config_id  bigint unique references app_public.guild_configs,
    name       text not null,
    icon       text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index on app_public.web_guilds(config_id);
-- timestamps
create trigger _100_timestamps
  before insert or update on app_public.web_guilds
  for each row
  execute procedure app_private.tg__timestamps();

/**********/

-- should only contain guilds with manage guild permissions
drop table if exists app_public.web_user_guilds cascade;
create table app_public.web_user_guilds (
    user_id     bigint not null,
    guild_id    bigint not null,
    permissions bigint not null,
    -- https://discord.com/developers/docs/topics/permissions#permissions
    -- true if user has manage_guild
    manage_guild boolean generated always
      as ((permissions & x'00000020'::bigint) = x'00000020'::bigint) stored,
    -- user_id fkey
    constraint web_user_guilds_user_id_fkey
        foreign key(user_id)
        references app_public.web_users(id)
            on delete cascade,
    -- guild_id fkey
    constraint web_user_guilds_guild_id_fkey
        foreign key(guild_id)
        references app_public.web_guilds(id)
            on delete cascade,
    -- composite key
    primary key (user_id, guild_id)
);
-- index on user_id since we only care about listing all a user's guilds
create index on app_public.web_user_guilds (user_id);
create index on app_public.web_user_guilds (guild_id);

-- get all guild ids a user is in where user has managed_guild permission
-- ignores servers user doesn't have manage_guild in.
-- shouldn't be necessary since only guilds are added if user has permission
-- but this is just in case i guess
drop function if exists app_public.current_user_managed_guild_ids() cascade;
create function app_public.current_user_managed_guild_ids() returns setof bigint as $$
  select guild_id
    from app_public.web_user_guilds
   where user_id = app_public.current_user_id()
     and manage_guild;
$$ language sql stable security definer set search_path = pg_catalog, public, pg_temp;

-- guilds rls 
alter table app_public.web_guilds enable row level security;
-- only allow selecting guilds user is and has manage perms
create policy select_self on app_public.web_guilds for
  select using (id in (select app_public.current_user_managed_guild_ids()));

grant select on app_public.web_guilds to :DATABASE_VISITOR;

-- enable rls to guild configs so it shows up
alter table app_public.guild_configs enable row level security;
create policy select_managed_guild on app_public.guild_configs
  for select using (id in (select app_public.current_user_managed_guild_ids()));
grant select on app_public.guild_configs to :DATABASE_VISITOR;

/**********/

drop function if exists app_public.current_user() cascade;
create function app_public.current_user() returns app_public.web_users as $$
  select web_users.*
    from app_public.web_users
   where id = app_public.current_user_id();
$$ language sql stable;
comment on function app_public.current_user() is
  E'The currently logged in user (or null if not logged in).';

/*******************/
/* main auth stuff */
/*******************/

-- This table contains secret information for each user_authentication; could
-- be things like access tokens, refresh tokens, profile information. Whatever
-- the passport strategy deems necessary.
drop table if exists app_private.user_authentication_secrets cascade;
create table app_private.user_authentication_secrets (
  user_id bigint not null primary key
    references app_public.web_users(id) on delete cascade,
  details jsonb not null default '{}'::jsonb
);
alter table app_private.user_authentication_secrets enable row level security;

/***********/

drop function if exists app_public.logout() cascade;
create function app_public.logout() returns void as $$
begin
  -- Delete the session
  delete from app_private.sessions
        where uuid = app_public.current_session_id();
  -- Clear the identifier from the transaction
  perform set_config('jwt.claims.session_id', '', true);
end;
$$ language plpgsql security definer volatile set search_path to pg_catalog, public, pg_temp;

/**********/

drop function if exists app_public.register_user(
  f_discord_user_id character varying,
  f_profile json,
  f_auth_details json
) cascade;
create function app_private.register_user(
  f_discord_user_id character varying,
  f_profile json,
  f_auth_details json
) returns app_public.web_users as $$
declare
  v_user app_public.web_users;
  v_username text;
  v_discriminator int;
  v_avatar text;
  v_user_guilds json;
begin
  -- Extract data from the user’s OAuth profile data.
  v_username := f_profile ->> 'username';
  v_discriminator := (f_profile ->> 'discriminator')::int;
  v_avatar := f_profile ->> 'avatar';
  v_user_guilds := f_profile -> 'guilds';

  -- Insert the new user
  insert into app_public.web_users (id, username, discriminator, avatar, details)
       values (f_discord_user_id::bigint, v_username, v_discriminator, v_avatar, f_profile)
    returning *
         into v_user;

  -- Insert guilds
  insert into app_public.web_guilds (id, config_id, name, icon)
       select (value->>'id')::bigint as guild_id,
              (select id from app_public.guild_configs where id = (value->>'id')::bigint),
              value->>'name',
              value->>'icon'
         from json_array_elements(v_user_guilds)
              -- only save guilds where user has manage guild permissions
        where ((value->>'permissions')::bigint & x'00000020'::bigint) = x'00000020'::bigint
           on conflict (id)
              do update
              set name = excluded.name,
                  icon = excluded.icon;

  -- Insert web guilds, should not conflict since new user means they will have no entries
  -- if this runs into error means it's re-registering a user I think
  insert into app_public.web_user_guilds (user_id, guild_id, permissions)
       select f_discord_user_id::bigint as user_id,
              (value->>'id')::bigint,
              (value->>'permissions')::bigint
         from json_array_elements(v_user_guilds)
        where ((value->>'permissions')::bigint & x'00000020'::bigint) = x'00000020'::bigint;

  -- Insert the user’s private account data (e.g. OAuth tokens)
  insert into app_private.user_authentication_secrets (user_id, details)
       values (f_discord_user_id::bigint, f_auth_details);

  return v_user;
end;
$$ language plpgsql volatile security definer set search_path to pg_catalog, public, pg_temp;

comment on function app_private.register_user(f_discord_user_id character varying, f_profile json, f_auth_details json) is
  E'Used to register a user from information gleaned from OAuth. Primarily used by login_or_register_user';

/**********/

-- should not be called if logged in already. graphile/starter uses this to link
-- additional oauth accounts if user is already logged in but since we only care
-- about Discord, if user is already logged in then there is no reason for them
-- to link another account, there is no other accounts to link
drop function if exists app_private.login_or_register_user(
  f_discord_user_id character varying,
  f_profile json,
  f_auth_details json
);
create function app_private.login_or_register_user(
  -- discord id as string, in case any u64 overflows in JS
  f_discord_user_id character varying,
  f_profile json,
  f_auth_details json
) returns app_public.web_users as $$
declare
  v_matched_user_id bigint;
  v_username text;
  v_discriminator int;
  v_avatar text;
  v_user_guilds json;
  v_user app_public.web_users;
begin
  -- check if there is already a user
  select id
    into v_matched_user_id
    from app_public.web_users
   where id = f_discord_user_id::bigint
   limit 1;

  v_username := f_profile ->> 'username';
  v_discriminator := (f_profile ->> 'discriminator')::int;
  v_avatar := f_profile ->> 'avatar';
  v_user_guilds := f_profile -> 'guilds';

  -- v_matched_user_id is if user already registered, f_user_id is null if not logged in
  if v_matched_user_id is null then
    -- create and return new user account
    -- do not need to handle linking new external oauth accounts to existing
    -- accounts since we only care about Discord oauth, if user already has
    -- existing account then there isn't anything to link
    return app_private.register_user(f_discord_user_id, f_profile, f_auth_details);
  else
    -- user exists, update oauth info to keep details in sync
    update app_public.web_users
           -- coalese new value is first since it returns first non-null value
       set username = coalesce(v_username, app_public.web_users.username),
           discriminator = coalesce(v_discriminator, app_public.web_users.discriminator),
           avatar = coalesce(v_avatar, app_public.web_users.avatar),
           details = f_profile
     where id = v_matched_user_id
           returning * into v_user;

    update app_private.user_authentication_secrets
       set details = f_auth_details
     where user_id = v_matched_user_id;

    -- Update guild data
    insert into app_public.web_guilds (id, config_id, name, icon)
         select (value->>'id')::bigint,
                (select id from app_public.guild_configs where id = (value->>'id')::bigint),
                value->>'name',
                value->>'icon'
           from json_array_elements(v_user_guilds)
          where ((value->>'permissions')::bigint & x'00000020'::bigint) = x'00000020'::bigint
             on conflict (id)
                do update
                set name = excluded.name,
                    icon = excluded.icon;

    -- Delete user guilds that they left
    -- ensure guild_id not in is not nulls
    delete from app_public.web_user_guilds
          where user_id = v_matched_user_id
            and guild_id not in (
                select (value->>'id')::bigint
                  from json_array_elements(v_user_guilds)
                 where guild_id is not null);

    -- Update user guilds
    insert into app_public.web_user_guilds (user_id, guild_id, permissions)
         select f_discord_user_id::bigint as user_id,
                (value->>'id')::bigint,
                (value->>'permissions')::bigint
           from json_array_elements(v_user_guilds)
                -- only save guilds where user has manage guild permissions
                where ((value->>'permissions')::bigint & x'00000020'::bigint) = x'00000020'::bigint
                on conflict (user_id, guild_id)
                   do update
                   set permissions = excluded.permissions;

    return v_user;
  end if;
end;
$$ language plpgsql volatile security definer set search_path to pg_catalog, public, pg_temp;

comment on function app_private.login_or_register_user(f_discord_user_id character varying, f_profile json, f_auth_details json) is
  E'This will log you in if an account already exists (based on OAuth Discord user_id) and return that, or create a new user account.';
