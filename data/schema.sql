--
-- PostgreSQL database dump
--

-- Dumped from database version 12.6
-- Dumped by pg_dump version 12.6 (Ubuntu 12.6-0ubuntu0.20.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: timescaledb; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;


--
-- Name: EXTENSION timescaledb; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION timescaledb IS 'Enables scalable inserts and complex queries for time-series data';


--
-- Name: app_hidden; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_hidden;


--
-- Name: app_private; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_private;


--
-- Name: app_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_public;


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: level_timeframe; Type: TYPE; Schema: app_hidden; Owner: -
--

CREATE TYPE app_hidden.level_timeframe AS ENUM (
    'ALL_TIME',
    'DAY',
    'WEEK',
    'MONTH'
);


--
-- Name: level_from_xp(bigint); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.level_from_xp(xp bigint) RETURNS bigint
    LANGUAGE sql IMMUTABLE
    AS $$
  select floor((sqrt(100 * (2 * xp + 25)) + 50) / 100)::bigint;
$$;


--
-- Name: total_xp_from_level(bigint); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.total_xp_from_level(level bigint) RETURNS bigint
    LANGUAGE sql IMMUTABLE
    AS $$
  select floor(((level - 1) * ((level - 1) + 1) / 2) * 100)::bigint;
$$;


--
-- Name: user_levels_filtered(app_hidden.level_timeframe, bigint); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.user_levels_filtered(f_timeframe app_hidden.level_timeframe, f_guild_id bigint) RETURNS TABLE(user_id bigint, xp bigint, xp_diff bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'app_public', 'pg_temp'
    AS $$
begin
  -- Bruh I don't know what this is either, but it works I think?
  -- aggregates are only if global (f_guild_id not provided)
  if f_guild_id is null then
    return query
           -- xp_diff should be xp gained only in a given category
           -- xp should always be total xp
           select app_public.user_levels.user_id,
                  -- total xp
                  sum(msg_all_time)::bigint as xp,
                  -- xp in timeframe
                  case
                       when f_timeframe = 'ALL_TIME' then null
                       when f_timeframe = 'DAY'      then sum(msg_day)::bigint
                       when f_timeframe = 'WEEK'     then sum(msg_week)::bigint
                       when f_timeframe = 'MONTH'    then sum(msg_month)::bigint
                  end xp_diff
             from app_public.user_levels
            where case
                       -- no filter when all
                       when f_timeframe = 'ALL_TIME' then true
                       when f_timeframe = 'DAY'
                            then extract(DOY  from last_msg) = extract(DOY  from now())
                             and extract(YEAR from last_msg) = extract(YEAR from now())
                       when f_timeframe = 'WEEK'
                            then extract(WEEK from last_msg) = extract(WEEK from now())
                             and extract(YEAR from last_msg) = extract(YEAR from now())
                       when f_timeframe = 'MONTH'
                            then extract(MONTH from last_msg) = extract(MONTH from now())
                             and extract(YEAR  from last_msg) = extract(YEAR  from now())
                  end
         group by app_public.user_levels.user_id;
  else
    -- guild query, no aggregates
    return query
           select app_public.user_levels.user_id,
                  -- total xp
                  msg_all_time as xp,
                  -- xp only in timeframe
                  case
                       when f_timeframe = 'ALL_TIME' then null
                       when f_timeframe = 'DAY'      then msg_day
                       when f_timeframe = 'WEEK'     then msg_week
                       when f_timeframe = 'MONTH'    then msg_month
                  end xp_diff
             from app_public.user_levels
            where guild_id = f_guild_id
              and case
                       -- no filter when all
                       when f_timeframe = 'ALL_TIME' then true
                       when f_timeframe = 'DAY'
                            then extract(DOY  from last_msg) = extract(DOY  from now())
                             and extract(YEAR from last_msg) = extract(YEAR from now())
                       when f_timeframe = 'WEEK'
                            then extract(WEEK from last_msg) = extract(WEEK from now())
                             and extract(YEAR from last_msg) = extract(YEAR from now())
                       when f_timeframe = 'MONTH'
                            then extract(MONTH from last_msg) = extract(MONTH from now())
                             and extract(YEAR  from last_msg) = extract(YEAR  from now())
                  end;
  end if;
end;
$$;


--
-- Name: xp_from_level(bigint); Type: FUNCTION; Schema: app_hidden; Owner: -
--

CREATE FUNCTION app_hidden.xp_from_level(level bigint) RETURNS bigint
    LANGUAGE sql IMMUTABLE
    AS $$
  select floor((pow(level, 2) + level) / 2 * 100 - (level * 100))::bigint;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: web_users; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.web_users (
    id bigint NOT NULL,
    username text NOT NULL,
    discriminator integer NOT NULL,
    avatar text,
    is_admin boolean DEFAULT false NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE web_users; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.web_users IS 'A user who can log in to the application.';


--
-- Name: COLUMN web_users.id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.web_users.id IS 'Unique identifier for the user. This should match their Discord ID.';


--
-- Name: COLUMN web_users.username; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.web_users.username IS 'Discord username of the user.';


--
-- Name: COLUMN web_users.discriminator; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.web_users.discriminator IS 'Discord disciminator of the user.';


--
-- Name: COLUMN web_users.avatar; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.web_users.avatar IS 'Discord avatar hash. Null if user does not have one.';


--
-- Name: COLUMN web_users.is_admin; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.web_users.is_admin IS 'If true, the user has elevated privileges.';


--
-- Name: COLUMN web_users.details; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.web_users.details IS 'Additional profile details extracted from Discord oauth';


--
-- Name: COLUMN web_users.created_at; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.web_users.created_at IS 'First registered on the application. Is not when a user created their Discord account.';


--
-- Name: login_or_register_user(character varying, json, json); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.login_or_register_user(f_discord_user_id character varying, f_profile json, f_auth_details json) RETURNS app_public.web_users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
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
    insert into app_public.cached_guilds (id, name, icon, features)
         select (value->>'id')::bigint,
                value->>'name',
                value->>'icon',
                array(select json_array_elements_text(value->'features'))
           from json_array_elements(v_user_guilds)
          where ((value->>'permissions')::bigint & x'00000020'::bigint) = x'00000020'::bigint
             or (value->>'owner')::boolean
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
    insert into app_public.web_user_guilds (user_id, guild_id, owner, permissions)
         select f_discord_user_id::bigint as user_id,
                (value->>'id')::bigint,
                (value->>'owner')::boolean,
                (value->>'permissions')::bigint
           from json_array_elements(v_user_guilds)
                -- only save guilds where user has manage guild permissions
                where ((value->>'permissions')::bigint & x'00000020'::bigint) = x'00000020'::bigint
                   or (value->>'owner')::boolean
                on conflict (user_id, guild_id)
                   do update
                   set permissions = excluded.permissions;

    return v_user;
  end if;
end;
$$;


--
-- Name: FUNCTION login_or_register_user(f_discord_user_id character varying, f_profile json, f_auth_details json); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.login_or_register_user(f_discord_user_id character varying, f_profile json, f_auth_details json) IS 'This will log you in if an account already exists (based on OAuth Discord user_id) and return that, or create a new user account.';


--
-- Name: register_user(character varying, json, json); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.register_user(f_discord_user_id character varying, f_profile json, f_auth_details json) RETURNS app_public.web_users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
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
  insert into app_public.cached_guilds (id, name, icon, features)
       select (value->>'id')::bigint as guild_id,
              value->>'name',
              value->>'icon',
              array(select json_array_elements_text(value->'features'))
         from json_array_elements(v_user_guilds)
              -- only save guilds where user has manage guild permissions
        where ((value->>'permissions')::bigint & x'00000020'::bigint) = x'00000020'::bigint
           or (value->>'owner')::boolean
           on conflict (id)
              do update
              set name = excluded.name,
                  icon = excluded.icon;

  -- Insert web guilds, should not conflict since new user means they will have no entries
  -- if this runs into error means it's re-registering a user I think
  insert into app_public.web_user_guilds (user_id, guild_id, owner, permissions)
       select f_discord_user_id::bigint as user_id,
              (value->>'id')::bigint,
              (value->>'owner')::boolean,
              (value->>'permissions')::bigint
         from json_array_elements(v_user_guilds)
        where ((value->>'permissions')::bigint & x'00000020'::bigint) = x'00000020'::bigint
           or (value->>'owner')::boolean;

  -- Insert the user’s private account data (e.g. OAuth tokens)
  insert into app_private.user_authentication_secrets (user_id, details)
       values (f_discord_user_id::bigint, f_auth_details);

  return v_user;
end;
$$;


--
-- Name: FUNCTION register_user(f_discord_user_id character varying, f_profile json, f_auth_details json); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.register_user(f_discord_user_id character varying, f_profile json, f_auth_details json) IS 'Used to register a user from information gleaned from OAuth. Primarily used by login_or_register_user';


--
-- Name: tg__timestamps(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg__timestamps() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  NEW.created_at = (case when TG_OP = 'INSERT' then NOW() else OLD.created_at end);
  NEW.updated_at = (case when TG_OP = 'UPDATE' and OLD.updated_at >= NOW() then OLD.updated_at + interval '1 millisecond' else NOW() end);
  return NEW;
end;
$$;


--
-- Name: FUNCTION tg__timestamps(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg__timestamps() IS 'This trigger should be called on all tables with created_at, updated_at - it ensures that they cannot be manipulated and that updated_at will always be larger than the previous updated_at.';


--
-- Name: current_session_id(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_session_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select nullif(pg_catalog.current_setting('jwt.claims.session_id', true), '')::uuid;
$$;


--
-- Name: FUNCTION current_session_id(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.current_session_id() IS 'Handy method to get the current session ID.';


--
-- Name: current_user(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public."current_user"() RETURNS app_public.web_users
    LANGUAGE sql STABLE
    AS $$
  select web_users.*
    from app_public.web_users
   where id = app_public.current_user_id();
$$;


--
-- Name: FUNCTION "current_user"(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public."current_user"() IS 'The currently logged in user (or null if not logged in).';


--
-- Name: current_user_id(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_user_id() RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select user_id
    from app_private.sessions
   where uuid = app_public.current_session_id();
$$;


--
-- Name: FUNCTION current_user_id(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.current_user_id() IS 'Handy method to get the current user ID for use in RLS policies, etc; in GraphQL, use `currentUser{id}` instead.';


--
-- Name: current_user_managed_guild_ids(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_user_managed_guild_ids() RETURNS SETOF bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
  select guild_id
    from app_public.web_user_guilds
   where user_id = app_public.current_user_id()
     and manage_guild
      or owner;
$$;


--
-- Name: logout(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.logout() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'pg_temp'
    AS $$
begin
  -- Delete the session
  delete from app_private.sessions
        where uuid = app_public.current_session_id();
  -- Clear the identifier from the transaction
  perform set_config('jwt.claims.session_id', '', true);
end;
$$;


--
-- Name: timeframe_user_levels(app_hidden.level_timeframe, bigint); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.timeframe_user_levels(timeframe app_hidden.level_timeframe, guild_id bigint DEFAULT NULL::bigint) RETURNS TABLE(user_id bigint, avatar_url text, username text, discriminator integer, xp bigint, xp_diff bigint, current_level bigint, gained_levels bigint, next_level_xp_required bigint, next_level_xp_progress bigint)
    LANGUAGE sql STABLE
    AS $$
  select t.user_id,
         avatar_url,
         name as username,
         discriminator,
         t.xp,
         t.xp_diff,
         current_level,
         gained_levels,
         next_level_xp_required,
         next_level_xp_progress
    from app_hidden.user_levels_filtered(timeframe, guild_id) t
         -- join the cached users to get username/avatar/discrim
         left join app_public.cached_users
                on user_id = id,
         -- lateral joins to reuse calculations, prob not needed considering
         -- they're immutable functions which should be optimized
         lateral (select app_hidden.level_from_xp(xp)
                         as current_level
                 ) c,
         -- required xp to level up ie
         -- level 2 -> 3 = 200xp
         -- level 3 -> 4 = 300xp, etc
         lateral (select current_level * 100
                         as next_level_xp_required
                 ) r,
         -- how much xp a user has progressed in a single level
         -- ie if they are level 2 and they have 150 xp, level 1 required 100xp
         -- this will return 50xp
         lateral (select xp - app_hidden.total_xp_from_level(current_level)
                         as next_level_xp_progress
                 ) p,
         lateral (select (current_level - app_hidden.level_from_xp(xp - t.xp_diff))
                         as gained_levels
                 ) g
      order by xp_diff desc,
               -- if xp_diff is null, then it will sort by xp (i think)
               xp desc,
               user_id desc;
$$;


--
-- Name: FUNCTION timeframe_user_levels(timeframe app_hidden.level_timeframe, guild_id bigint); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.timeframe_user_levels(timeframe app_hidden.level_timeframe, guild_id bigint) IS 'Leaderboard for given timeframe and optional guild. If guild is null, it is the global leaderboard';


--
-- Name: failures; Type: TABLE; Schema: app_hidden; Owner: -
--

CREATE TABLE app_hidden.failures (
    failure_id text NOT NULL,
    max_attempts integer DEFAULT 25 NOT NULL,
    attempt_count integer NOT NULL,
    last_attempt timestamp without time zone NOT NULL,
    next_attempt timestamp without time zone GENERATED ALWAYS AS ((last_attempt + (exp((LEAST(10, attempt_count))::double precision) * '00:00:01'::interval))) STORED NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.sessions (
    uuid uuid DEFAULT public.gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_active timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_authentication_secrets; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.user_authentication_secrets (
    user_id bigint NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: cached_guilds; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.cached_guilds (
    id bigint NOT NULL,
    name text NOT NULL,
    icon text,
    splash text,
    banner text,
    features text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE cached_guilds; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.cached_guilds IS '@omit all,filter';


--
-- Name: cached_users; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.cached_users (
    id bigint NOT NULL,
    avatar_url text NOT NULL,
    name text NOT NULL,
    discriminator integer NOT NULL,
    last_checked timestamp without time zone NOT NULL
);


--
-- Name: TABLE cached_users; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.cached_users IS '@omit all,filter';


--
-- Name: feed_items; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.feed_items (
    feed_id text NOT NULL,
    item_id text NOT NULL
);


--
-- Name: feed_subscriptions; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.feed_subscriptions (
    feed_id text NOT NULL,
    guild_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    mention_role bigint
);


--
-- Name: feeds; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.feeds (
    feed_id text NOT NULL,
    metadata jsonb
);


--
-- Name: guild_configs; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.guild_configs (
    id bigint NOT NULL,
    prefix text,
    join_msg text,
    join_msg_enabled boolean DEFAULT true NOT NULL,
    join_react text,
    leave_msg text,
    leave_msg_enabled boolean DEFAULT true NOT NULL,
    msg_channel bigint,
    role_channel bigint,
    role_config jsonb,
    role_enabled boolean DEFAULT true NOT NULL,
    invite_guard boolean DEFAULT false NOT NULL,
    log_msg bigint,
    log_msg_enabled boolean DEFAULT true NOT NULL,
    log_mod bigint,
    log_mod_enabled boolean DEFAULT true NOT NULL,
    log_member bigint,
    log_member_enabled boolean DEFAULT true NOT NULL,
    mute_role bigint,
    mute_duration bigint,
    mute_dm_text text,
    mute_dm_enabled boolean DEFAULT true NOT NULL,
    warn_dm_text text,
    warn_dm_enabled boolean DEFAULT true NOT NULL,
    max_mention integer,
    disabled_channels bigint[]
);


--
-- Name: members; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.members (
    guild_id bigint NOT NULL,
    user_id bigint NOT NULL,
    join_time timestamp without time zone NOT NULL
);


--
-- Name: messages; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.messages (
    message_id bigint NOT NULL,
    author_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    created timestamp without time zone NOT NULL,
    content text NOT NULL,
    msg jsonb NOT NULL
);


--
-- Name: mod_logs; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.mod_logs (
    guild_id bigint NOT NULL,
    case_id bigint NOT NULL,
    action text NOT NULL,
    action_time timestamp without time zone NOT NULL,
    pending boolean NOT NULL,
    user_id bigint NOT NULL,
    user_tag text NOT NULL,
    executor_id bigint,
    reason text,
    msg_id bigint
);


--
-- Name: mutes; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.mutes (
    guild_id bigint NOT NULL,
    user_id bigint NOT NULL,
    start_time timestamp without time zone NOT NULL,
    end_time timestamp without time zone,
    pending boolean DEFAULT false NOT NULL,
    case_id bigint
);


--
-- Name: notifications; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.notifications (
    user_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    keyword text NOT NULL
);


--
-- Name: reminders; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.reminders (
    user_id bigint NOT NULL,
    description text NOT NULL,
    set_at timestamp without time zone NOT NULL,
    expire_at timestamp without time zone NOT NULL
);


--
-- Name: tags; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.tags (
    owner_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    tag_name text NOT NULL,
    content text NOT NULL,
    use_count bigint NOT NULL,
    created timestamp without time zone NOT NULL
);


--
-- Name: user_levels; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.user_levels (
    user_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    msg_all_time bigint NOT NULL,
    msg_month bigint NOT NULL,
    msg_week bigint NOT NULL,
    msg_day bigint NOT NULL,
    last_msg timestamp without time zone NOT NULL
);


--
-- Name: TABLE user_levels; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.user_levels IS '@omit all,filter';


--
-- Name: users; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.users (
    id bigint NOT NULL,
    is_patron boolean NOT NULL,
    patron_emoji text,
    rep bigint NOT NULL,
    fishies bigint NOT NULL,
    last_rep timestamp without time zone,
    last_fishies timestamp without time zone,
    lastfm_username text,
    profile_data jsonb
);


--
-- Name: web_user_guilds; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.web_user_guilds (
    user_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    owner boolean NOT NULL,
    permissions bigint NOT NULL,
    manage_guild boolean GENERATED ALWAYS AS (((permissions & ('00000000000000000000000000100000'::"bit")::bigint) = ('00000000000000000000000000100000'::"bit")::bigint)) STORED
);


--
-- Name: failures failures_pkey; Type: CONSTRAINT; Schema: app_hidden; Owner: -
--

ALTER TABLE ONLY app_hidden.failures
    ADD CONSTRAINT failures_pkey PRIMARY KEY (failure_id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (uuid);


--
-- Name: user_authentication_secrets user_authentication_secrets_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_authentication_secrets
    ADD CONSTRAINT user_authentication_secrets_pkey PRIMARY KEY (user_id);


--
-- Name: cached_guilds cached_guilds_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.cached_guilds
    ADD CONSTRAINT cached_guilds_pkey PRIMARY KEY (id);


--
-- Name: cached_users cached_users_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.cached_users
    ADD CONSTRAINT cached_users_pkey PRIMARY KEY (id);


--
-- Name: feed_items feed_items_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.feed_items
    ADD CONSTRAINT feed_items_pkey PRIMARY KEY (feed_id, item_id);


--
-- Name: feed_subscriptions feed_subscriptions_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.feed_subscriptions
    ADD CONSTRAINT feed_subscriptions_pkey PRIMARY KEY (feed_id, channel_id);


--
-- Name: feeds feeds_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.feeds
    ADD CONSTRAINT feeds_pkey PRIMARY KEY (feed_id);


--
-- Name: guild_configs guild_configs_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.guild_configs
    ADD CONSTRAINT guild_configs_pkey PRIMARY KEY (id);


--
-- Name: members members_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.members
    ADD CONSTRAINT members_pkey PRIMARY KEY (guild_id, user_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (message_id);


--
-- Name: mod_logs mod_logs_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.mod_logs
    ADD CONSTRAINT mod_logs_pkey PRIMARY KEY (guild_id, case_id);


--
-- Name: mutes mutes_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.mutes
    ADD CONSTRAINT mutes_pkey PRIMARY KEY (guild_id, user_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (user_id, guild_id, keyword);


--
-- Name: reminders reminders_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.reminders
    ADD CONSTRAINT reminders_pkey PRIMARY KEY (user_id, set_at);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (guild_id, tag_name);


--
-- Name: user_levels user_levels_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_levels
    ADD CONSTRAINT user_levels_pkey PRIMARY KEY (user_id, guild_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: web_user_guilds web_user_guilds_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.web_user_guilds
    ADD CONSTRAINT web_user_guilds_pkey PRIMARY KEY (user_id, guild_id);


--
-- Name: web_users web_users_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.web_users
    ADD CONSTRAINT web_users_pkey PRIMARY KEY (id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: app_private; Owner: -
--

CREATE INDEX sessions_user_id_idx ON app_private.sessions USING btree (user_id);


--
-- Name: notification_guild_id_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX notification_guild_id_idx ON app_public.notifications USING btree (guild_id);


--
-- Name: notification_keyword_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX notification_keyword_idx ON app_public.notifications USING btree (keyword);


--
-- Name: tag_name_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX tag_name_idx ON app_public.tags USING gin (tag_name public.gin_trgm_ops);


--
-- Name: web_user_guilds_guild_id_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX web_user_guilds_guild_id_idx ON app_public.web_user_guilds USING btree (guild_id);


--
-- Name: web_user_guilds_user_id_idx; Type: INDEX; Schema: app_public; Owner: -
--

CREATE INDEX web_user_guilds_user_id_idx ON app_public.web_user_guilds USING btree (user_id);


--
-- Name: cached_guilds _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.cached_guilds FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: web_users _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_public.web_users FOR EACH ROW EXECUTE FUNCTION app_private.tg__timestamps();


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.web_users(id) ON DELETE CASCADE;


--
-- Name: user_authentication_secrets user_authentication_secrets_user_id_fkey; Type: FK CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_authentication_secrets
    ADD CONSTRAINT user_authentication_secrets_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.web_users(id) ON DELETE CASCADE;


--
-- Name: feed_subscriptions fk_feed_subscription_feed_id; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.feed_subscriptions
    ADD CONSTRAINT fk_feed_subscription_feed_id FOREIGN KEY (feed_id) REFERENCES app_public.feeds(feed_id) ON DELETE CASCADE;


--
-- Name: mutes fk_mod_action; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.mutes
    ADD CONSTRAINT fk_mod_action FOREIGN KEY (guild_id, case_id) REFERENCES app_public.mod_logs(guild_id, case_id);


--
-- Name: guild_configs guild_configs_cached_guild_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.guild_configs
    ADD CONSTRAINT guild_configs_cached_guild_fkey FOREIGN KEY (id) REFERENCES app_public.cached_guilds(id);


--
-- Name: web_user_guilds web_user_guilds_guild_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.web_user_guilds
    ADD CONSTRAINT web_user_guilds_guild_id_fkey FOREIGN KEY (guild_id) REFERENCES app_public.cached_guilds(id) ON DELETE CASCADE;


--
-- Name: web_user_guilds web_user_guilds_user_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.web_user_guilds
    ADD CONSTRAINT web_user_guilds_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.web_users(id) ON DELETE CASCADE;


--
-- Name: sessions; Type: ROW SECURITY; Schema: app_private; Owner: -
--

ALTER TABLE app_private.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_authentication_secrets; Type: ROW SECURITY; Schema: app_private; Owner: -
--

ALTER TABLE app_private.user_authentication_secrets ENABLE ROW LEVEL SECURITY;

--
-- Name: cached_guilds; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.cached_guilds ENABLE ROW LEVEL SECURITY;

--
-- Name: cached_users; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.cached_users ENABLE ROW LEVEL SECURITY;

--
-- Name: guild_configs; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.guild_configs ENABLE ROW LEVEL SECURITY;

--
-- Name: cached_guilds select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.cached_guilds FOR SELECT USING (true);


--
-- Name: cached_users select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.cached_users FOR SELECT USING (true);


--
-- Name: tags select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.tags FOR SELECT USING (true);


--
-- Name: user_levels select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.user_levels FOR SELECT USING (true);


--
-- Name: guild_configs select_managed_guild; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_managed_guild ON app_public.guild_configs FOR SELECT USING ((id IN ( SELECT app_public.current_user_managed_guild_ids() AS current_user_managed_guild_ids)));


--
-- Name: web_users select_self; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_self ON app_public.web_users FOR SELECT USING ((id = app_public.current_user_id()));


--
-- Name: web_user_guilds select_web_user_guilds; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_web_user_guilds ON app_public.web_user_guilds FOR SELECT USING ((manage_guild OR owner));


--
-- Name: tags; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.tags ENABLE ROW LEVEL SECURITY;

--
-- Name: guild_configs update_managed_guild; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_managed_guild ON app_public.guild_configs FOR UPDATE USING ((id IN ( SELECT app_public.current_user_managed_guild_ids() AS current_user_managed_guild_ids)));


--
-- Name: web_users update_self; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_self ON app_public.web_users FOR UPDATE USING ((id = app_public.current_user_id()));


--
-- Name: user_levels; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.user_levels ENABLE ROW LEVEL SECURITY;

--
-- Name: web_user_guilds; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.web_user_guilds ENABLE ROW LEVEL SECURITY;

--
-- Name: web_users; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.web_users ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA app_hidden; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA app_hidden TO sushii_visitor;


--
-- Name: SCHEMA app_public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA app_public TO sushii_visitor;


--
-- Name: FUNCTION level_from_xp(xp bigint); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.level_from_xp(xp bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.level_from_xp(xp bigint) TO sushii_visitor;


--
-- Name: FUNCTION total_xp_from_level(level bigint); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.total_xp_from_level(level bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.total_xp_from_level(level bigint) TO sushii_visitor;


--
-- Name: FUNCTION user_levels_filtered(f_timeframe app_hidden.level_timeframe, f_guild_id bigint); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.user_levels_filtered(f_timeframe app_hidden.level_timeframe, f_guild_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.user_levels_filtered(f_timeframe app_hidden.level_timeframe, f_guild_id bigint) TO sushii_visitor;


--
-- Name: FUNCTION xp_from_level(level bigint); Type: ACL; Schema: app_hidden; Owner: -
--

REVOKE ALL ON FUNCTION app_hidden.xp_from_level(level bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION app_hidden.xp_from_level(level bigint) TO sushii_visitor;


--
-- Name: TABLE web_users; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.web_users TO sushii_visitor;


--
-- Name: FUNCTION login_or_register_user(f_discord_user_id character varying, f_profile json, f_auth_details json); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.login_or_register_user(f_discord_user_id character varying, f_profile json, f_auth_details json) FROM PUBLIC;


--
-- Name: FUNCTION register_user(f_discord_user_id character varying, f_profile json, f_auth_details json); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.register_user(f_discord_user_id character varying, f_profile json, f_auth_details json) FROM PUBLIC;


--
-- Name: FUNCTION tg__timestamps(); Type: ACL; Schema: app_private; Owner: -
--

REVOKE ALL ON FUNCTION app_private.tg__timestamps() FROM PUBLIC;


--
-- Name: FUNCTION current_session_id(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_session_id() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_session_id() TO sushii_visitor;


--
-- Name: FUNCTION "current_user"(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public."current_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public."current_user"() TO sushii_visitor;


--
-- Name: FUNCTION current_user_id(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_id() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_id() TO sushii_visitor;


--
-- Name: FUNCTION current_user_managed_guild_ids(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.current_user_managed_guild_ids() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.current_user_managed_guild_ids() TO sushii_visitor;


--
-- Name: FUNCTION logout(); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.logout() FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.logout() TO sushii_visitor;


--
-- Name: FUNCTION timeframe_user_levels(timeframe app_hidden.level_timeframe, guild_id bigint); Type: ACL; Schema: app_public; Owner: -
--

REVOKE ALL ON FUNCTION app_public.timeframe_user_levels(timeframe app_hidden.level_timeframe, guild_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION app_public.timeframe_user_levels(timeframe app_hidden.level_timeframe, guild_id bigint) TO sushii_visitor;


--
-- Name: TABLE cached_guilds; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.cached_guilds TO sushii_visitor;


--
-- Name: TABLE cached_users; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.cached_users TO sushii_visitor;


--
-- Name: TABLE guild_configs; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.prefix; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(prefix) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.join_msg; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(join_msg) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.join_msg_enabled; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(join_msg_enabled) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.join_react; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(join_react) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.leave_msg; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(leave_msg) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.leave_msg_enabled; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(leave_msg_enabled) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.msg_channel; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(msg_channel) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.role_channel; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(role_channel) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.role_config; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(role_config) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.role_enabled; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(role_enabled) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.invite_guard; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(invite_guard) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.log_msg; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(log_msg) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.log_msg_enabled; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(log_msg_enabled) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.log_mod; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(log_mod) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.log_mod_enabled; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(log_mod_enabled) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.log_member; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(log_member) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.log_member_enabled; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(log_member_enabled) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.mute_role; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(mute_role) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.mute_duration; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(mute_duration) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.mute_dm_text; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(mute_dm_text) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.mute_dm_enabled; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(mute_dm_enabled) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.warn_dm_text; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(warn_dm_text) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.warn_dm_enabled; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(warn_dm_enabled) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.max_mention; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(max_mention) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: COLUMN guild_configs.disabled_channels; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(disabled_channels) ON TABLE app_public.guild_configs TO sushii_visitor;


--
-- Name: TABLE tags; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.tags TO sushii_visitor;


--
-- Name: TABLE user_levels; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.user_levels TO sushii_visitor;


--
-- Name: TABLE web_user_guilds; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT ON TABLE app_public.web_user_guilds TO sushii_visitor;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app_hidden; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_hidden REVOKE ALL ON SEQUENCES  FROM sushii;
ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_hidden GRANT SELECT,USAGE ON SEQUENCES  TO sushii_visitor;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: app_hidden; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_hidden REVOKE ALL ON FUNCTIONS  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_hidden REVOKE ALL ON FUNCTIONS  FROM sushii;
ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_hidden GRANT ALL ON FUNCTIONS  TO sushii_visitor;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_public REVOKE ALL ON SEQUENCES  FROM sushii;
ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_public GRANT SELECT,USAGE ON SEQUENCES  TO sushii_visitor;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: app_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_public REVOKE ALL ON FUNCTIONS  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_public REVOKE ALL ON FUNCTIONS  FROM sushii;
ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA app_public GRANT ALL ON FUNCTIONS  TO sushii_visitor;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA public REVOKE ALL ON SEQUENCES  FROM sushii;
ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES  TO sushii_visitor;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA public REVOKE ALL ON FUNCTIONS  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA public REVOKE ALL ON FUNCTIONS  FROM sushii;
ALTER DEFAULT PRIVILEGES FOR ROLE sushii IN SCHEMA public GRANT ALL ON FUNCTIONS  TO sushii_visitor;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE sushii REVOKE ALL ON FUNCTIONS  FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

