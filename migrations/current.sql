-- Levels roles!

-- Add generated level column to user rank row for convenience
alter table app_public.user_levels
  drop column if exists level;
alter table app_public.user_levels
  add column level bigint not null generated always as (
    app_hidden.level_from_xp(msg_all_time)
  ) stored;


-- Add table for level roles
drop table if exists app_public.level_roles cascade;
create table if not exists app_public.level_roles (
  guild_id     bigint not null,
  role_id      bigint not null,
  add_level    bigint,
  remove_level bigint,

  primary key (guild_id, role_id),
  constraint chk_at_least_one_level check (num_nonnulls(add_level, remove_level) >= 1),
  constraint chk_add_before_remove  check (add_level < remove_level)
);

-- Type of level role override, e.g. letting a user keep a role even if they
-- exceed remove_level
-- or preventing a user from receiving a role after they reach the level
drop type if exists app_public.level_role_override_type cascade;
create type app_public.level_role_override_type as enum (
  'grant',
  'block'
);

-- Table for level role overrides
drop table if exists app_public.level_role_overrides cascade;
create table if not exists app_public.level_role_overrides (
  guild_id bigint not null,
  role_id  bigint not null,
  user_id  bigint not null,
  type     app_public.level_role_override_type not null,

  primary key (guild_id, role_id, user_id),
  -- delete override if the level role is deleted
  foreign key (guild_id, role_id)
    references app_public.level_roles (guild_id, role_id)
    on delete cascade
);

-- Custom type for level role response for process to know which roles were
-- granted or removed
drop type if exists app_public.user_xp_update_result cascade;
create type app_public.user_xp_update_result as (
  role_id bigint,
  action  text
);

-- Updates a user's XP, resetting any relevant counters and returns any roles to add or to remove
drop function if exists app_hidden.update_user_xp(
  guild_id bigint,
  user_id bigint
) cascade;
create function app_hidden.update_user_xp(
  guild_id bigint,
  user_id bigint
) returns setof app_public.user_xp_update_result as $$
#variable_conflict use_column
declare
  new_level bigint;
begin
  insert into app_public.user_levels (
    guild_id,
    user_id,
    msg_all_time,
    msg_month,
    msg_week,
    msg_day,
    last_msg
  )
    values ($1, $2, 5, 5, 5, 5, now())
    on conflict (guild_id, user_id) do update
      set last_msg = now(),
      msg_all_time = app_public.user_levels.msg_all_time + 5,
      msg_month = (
        case
          when extract(MONTH from app_public.user_levels.last_msg) = extract(MONTH from now())
           and extract(YEAR  from app_public.user_levels.last_msg) = extract(YEAR  from now())
            then app_public.user_levels.msg_month + 5
          else 5
        end
      ),
      msg_week = (
        case
          when extract(WEEK from app_public.user_levels.last_msg) = extract(WEEK from now())
           and extract(YEAR from app_public.user_levels.last_msg) = extract(YEAR from now())
            then app_public.user_levels.msg_month + 5
          else 5
        end
      ),
      msg_day = (
        case
          when extract(DAY  from app_public.user_levels.last_msg) = extract(DAY  from now())
           and extract(YEAR from app_public.user_levels.last_msg) = extract(YEAR from now())
            then app_public.user_levels.msg_month + 5
          else 5
        end
      )
      where app_public.user_levels.last_msg < (now() - interval '1 minute')
    returning level into new_level;

  if new_level is null then
    return;
  end if;

  -- Get all level roles that apply to this user
  return query select
    app_public.level_roles.role_id,
    case
      -- remove first case since we want remove to have priority
      when remove_level is not null and new_level >= remove_level then 'remove'
      when add_level is not null    and new_level >= add_level    then 'add'
    end as action
  from app_public.level_roles
    left outer join app_public.level_role_overrides
      on app_public.level_roles.guild_id = app_public.level_role_overrides.guild_id
     and app_public.level_roles.role_id  = app_public.level_role_overrides.role_id
     and app_public.level_role_overrides.user_id = update_user_xp.user_id
    where app_public.level_roles.guild_id = $1
      -- if add_level is defined AND if user does NOT have a 'block' on the role
      and (
        app_public.level_roles.add_level is not null
        and
        app_public.level_roles.add_level <= new_level
        and
        (
          -- no override for this role, skip
          app_public.level_role_overrides.type is null
          or
          -- override to block the role for this user
          app_public.level_role_overrides.type != 'block'
        )
      )
      or (
        app_public.level_roles.remove_level is not null
        and
        app_public.level_roles.remove_level > new_level
        and
        (
          -- no override for this role, allow removals
          app_public.level_role_overrides.type is null
          or
          -- override is to grant the role for this user, must be NOT grant to return
          app_public.level_role_overrides.type != 'grant'
        )
      );
end;
$$ language plpgsql volatile security definer set search_path to pg_catalog, public, app_public, pg_temp;
