-- postgraphile auth stuff

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

drop function if exists app_public.tg__timestamps() cascade;
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
drop table if exists app_public.web_users cascade;
create table app_public.web_users (
    -- discord user ID
    id            bigint      primary key,
    -- discord username/discrim
    username      text        not null,
    discriminator int         not null,
    avatar_url    text        not null,
    is_admin      boolean     not null default false,
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
comment on column app_public.web_users.avatar_url is
  E'Discord avatar URL.';
comment on column app_public.web_users.is_admin is
  E'If true, the user has elevated privileges.';
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
    name       text not null,
    icon_url   text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
-- timestamps
create trigger _100_timestamps
  before insert or update on app_public.web_guilds
  for each row
  execute procedure app_private.tg__timestamps();

drop table if exists app_public.web_user_guilds cascade;
create table app_public.web_user_guilds (
    user_id     bigint not null,
    guild_id    bigint not null,
    permissions bigint not null,
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

-- get all guild ids a user is in
drop function if exists app_public.current_user_guild_ids() cascade;
create function app_public.current_user_guild_ids() returns setof bigint as $$
  select guild_id
    from app_public.web_user_guilds
   where user_id = app_public.current_user_id();
$$ language sql stable security definer set search_path = pg_catalog, public, pg_temp;

-- guilds rls 
alter table app_public.web_guilds enable row level security;
-- only allow selecting guilds user is in
create policy select_self on app_public.web_guilds for select using (id in (select app_public.current_user_guild_ids()));

grant select on app_public.web_guilds to :DATABASE_VISITOR;

/**********/

drop function if exists app_public.current_user() cascade;
create function app_public.current_user() returns app_public.web_users as $$
  select web_users.*
    from app_public.web_users
   where id = app_public.current_user_id();
$$ language sql stable;
comment on function app_public.current_user() is
  E'The currently logged in user (or null if not logged in).';

/***********************/
/* main auth functions */
/***********************/

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

drop function if exists app_public.really_create_user() cascade;
create function app_private.really_create_user(
  username citext,
  email text,
  email_is_verified bool,
  name text,
  avatar_url text,
  password text default null
) returns app_public.web_users as $$
declare
  v_user app_public.web_users;
  v_username citext = username;
begin
  if password is not null then
    perform app_private.assert_valid_password(password);
  end if;
  if email is null then
    raise exception 'Email is required' using errcode = 'MODAT';
  end if;

  -- Insert the new user
  insert into app_public.web_users (username, name, avatar_url) values
    (v_username, name, avatar_url)
    returning * into v_user;

	-- Add the user's email
  insert into app_public.user_emails (user_id, email, is_verified, is_primary)
  values (v_user.id, email, email_is_verified, email_is_verified);

  -- Store the password
  if password is not null then
    update app_private.user_secrets
    set password_hash = crypt(password, gen_salt('bf'))
    where user_id = v_user.id;
  end if;

  -- Refresh the user
  select * into v_user from app_public.web_users where id = v_user.id;

  return v_user;
end;
$$ language plpgsql volatile set search_path to pg_catalog, public, pg_temp;

comment on function app_private.really_create_user(username citext, email text, email_is_verified bool, name text, avatar_url text, password text) is
  E'Creates a user account. All arguments are optional, it trusts the calling method to perform sanitisation.';

/**********/

drop function if exists app_public.register_user() cascade;
create function app_private.register_user(
  f_service character varying,
  f_identifier character varying,
  f_profile json,
  f_auth_details json,
  f_email_is_verified boolean default false
) returns app_public.web_users as $$
declare
  v_user app_public.web_users;
  v_email citext;
  v_name text;
  v_username citext;
  v_avatar_url text;
  v_user_authentication_id uuid;
begin
  -- Extract data from the user’s OAuth profile data.
  v_email := f_profile ->> 'email';
  v_name := f_profile ->> 'name';
  v_username := f_profile ->> 'username';
  v_avatar_url := f_profile ->> 'avatar_url';

  -- Sanitise the username, and make it unique if necessary.
  if v_username is null then
    v_username = coalesce(v_name, 'user');
  end if;
  v_username = regexp_replace(v_username, '^[^a-z]+', '', 'gi');
  v_username = regexp_replace(v_username, '[^a-z0-9]+', '_', 'gi');
  if v_username is null or length(v_username) < 3 then
    v_username = 'user';
  end if;
  select (
    case
    when i = 0 then v_username
    else v_username || i::text
    end
  ) into v_username from generate_series(0, 1000) i
  where not exists(
    select 1
    from app_public.web_users
    where users.username = (
      case
      when i = 0 then v_username
      else v_username || i::text
      end
    )
  )
  limit 1;

  -- Create the user account
  v_user = app_private.really_create_user(
    username => v_username,
    email => v_email,
    email_is_verified => f_email_is_verified,
    name => v_name,
    avatar_url => v_avatar_url
  );

  -- Insert the user’s private account data (e.g. OAuth tokens)
  insert into app_public.user_authentications (user_id, service, identifier, details) values
    (v_user.id, f_service, f_identifier, f_profile) returning id into v_user_authentication_id;
  insert into app_private.user_authentication_secrets (user_authentication_id, details) values
    (v_user_authentication_id, f_auth_details);

  return v_user;
end;
$$ language plpgsql volatile security definer set search_path to pg_catalog, public, pg_temp;

comment on function app_private.register_user(f_service character varying, f_identifier character varying, f_profile json, f_auth_details json, f_email_is_verified boolean) is
  E'Used to register a user from information gleaned from OAuth. Primarily used by link_or_register_user';

/**********/


drop function if exists app_private.link_or_register_user();
create function app_private.link_or_register_user(
  -- discord id as text
  f_user_id text,
  f_service character varying,
  f_identifier character varying,
  f_profile json,
  f_auth_details json
) returns app_public.web_users as $$
declare
  v_matched_user_id uuid;
  v_matched_authentication_id uuid;
  v_email citext;
  v_name text;
  v_avatar_url text;
  v_user app_public.web_users;
  v_user_email app_public.user_emails;
begin
  -- See if a user account already matches these details
  select id, user_id
    into v_matched_authentication_id, v_matched_user_id
    from app_public.user_authentications
    where service = f_service
    and identifier = f_identifier
    limit 1;

  if v_matched_user_id is not null and f_user_id is not null and v_matched_user_id <> f_user_id then
    raise exception 'A different user already has this account linked.' using errcode = 'TAKEN';
  end if;

  v_email = f_profile ->> 'email';
  v_name := f_profile ->> 'name';
  v_avatar_url := f_profile ->> 'avatar_url';

  if v_matched_authentication_id is null then
    if f_user_id is not null then
      -- Link new account to logged in user account
      insert into app_public.user_authentications (user_id, service, identifier, details) values
        (f_user_id, f_service, f_identifier, f_profile) returning id, user_id into v_matched_authentication_id, v_matched_user_id;
      insert into app_private.user_authentication_secrets (user_authentication_id, details) values
        (v_matched_authentication_id, f_auth_details);
      perform graphile_worker.add_job(
        'user__audit',
        json_build_object(
          'type', 'linked_account',
          'user_id', f_user_id,
          'extra1', f_service,
          'extra2', f_identifier,
          'current_user_id', app_public.current_user_id()
        ));
    elsif v_email is not null then
      -- See if the email is registered
      select * into v_user_email from app_public.user_emails where email = v_email and is_verified is true;
      if v_user_email is not null then
        -- User exists!
        insert into app_public.user_authentications (user_id, service, identifier, details) values
          (v_user_email.user_id, f_service, f_identifier, f_profile) returning id, user_id into v_matched_authentication_id, v_matched_user_id;
        insert into app_private.user_authentication_secrets (user_authentication_id, details) values
          (v_matched_authentication_id, f_auth_details);
        perform graphile_worker.add_job(
          'user__audit',
          json_build_object(
            'type', 'linked_account',
            'user_id', f_user_id,
            'extra1', f_service,
            'extra2', f_identifier,
            'current_user_id', app_public.current_user_id()
          ));
      end if;
    end if;
  end if;
  if v_matched_user_id is null and f_user_id is null and v_matched_authentication_id is null then
    -- Create and return a new user account
    return app_private.register_user(f_service, f_identifier, f_profile, f_auth_details, true);
  else
    if v_matched_authentication_id is not null then
      update app_public.user_authentications
        set details = f_profile
        where id = v_matched_authentication_id;
      update app_private.user_authentication_secrets
        set details = f_auth_details
        where user_authentication_id = v_matched_authentication_id;
      update app_public.web_users
        set
          name = coalesce(users.name, v_name),
          avatar_url = coalesce(users.avatar_url, v_avatar_url)
        where id = v_matched_user_id
        returning  * into v_user;
      return v_user;
    else
      -- v_matched_authentication_id is null
      -- -> v_matched_user_id is null (they're paired)
      -- -> f_user_id is not null (because the if clause above)
      -- -> v_matched_authentication_id is not null (because of the separate if block above creating a user_authentications)
      -- -> contradiction.
      raise exception 'This should not occur';
    end if;
  end if;
end;
$$ language plpgsql volatile security definer set search_path to pg_catalog, public, pg_temp;

comment on function app_private.link_or_register_user(f_user_id uuid, f_service character varying, f_identifier character varying, f_profile json, f_auth_details json) is
  E'If you''re logged in, this will link an additional OAuth login to your account if necessary. If you''re logged out it may find if an account already exists (based on OAuth details or email address) and return that, or create a new user account if necessary.';
