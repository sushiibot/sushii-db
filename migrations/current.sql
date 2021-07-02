CREATE OR REPLACE FUNCTION pseudo_encrypt(VALUE bigint) returns bigint AS $$
DECLARE
l1 bigint;
l2 bigint;
r1 bigint;
r2 bigint;
i int:=0;
BEGIN
    l1:= (VALUE >> 32) & 4294967295::bigint;
    r1:= VALUE & 4294967295;
    WHILE i < 3 LOOP
        l2 := r1;
        r2 := l1 # ((((1366.0 * r1 + 150889) % 714025) / 714025.0) * 32767*32767)::int;
        l1 := l2;
        r1 := r2;
        i := i + 1;
    END LOOP;
RETURN ((l1::bigint << 32) + r1);
END;
$$ LANGUAGE plpgsql strict immutable;

drop table if exists app_private.staff cascade;
create table app_private.staff (
    -- Discord ID
    user_id bigint primary key,
    permissions text[] not null default ARRAY[]::text[]
);
create index on app_private.staff(user_id);

-- Populate table with staff users, just me really
insert into app_private.staff(user_id, permissions) values
  (150443906511667200, ARRAY['admin']);

-- If current user has the provided permissions
drop function if exists app_public.current_user_with_permissions(permission_one_of text[]) cascade;
create function app_public.current_user_with_permissions(permission_one_of text[]) returns boolean as $$
  select app_public.current_user_id() in (
      select user_id
        from app_private.staff
      where permissions && permission_one_of
  );
$$ language sql stable security definer set search_path = pg_catalog, public, pg_temp;

drop sequence if exists app_public.guild_rule_ids cascade;
create sequence app_public.guild_rule_ids;

drop table if exists app_public.guild_rule_sets cascade;
create table app_public.guild_rule_sets (
    id          bigint      not null primary key default pseudo_encrypt(nextval('app_public.guild_rule_ids')::bigint),
    -- null if it is a global rule set
    guild_id    bigint,
    name        text        not null,
    description text,
    -- if guild_id == null: global toggle to disable global rule sets
    -- if guild_id == some: disable custom rule set with no config
    enabled     boolean     not null default true,
    editable    boolean     not null default true,
    author      bigint,
    category    text,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

-- configs are separate to prevent duplication of rule sets, ie.
-- global default rule_sets that cannot be edited
drop table if exists app_public.guild_rule_set_configs cascade;
create table app_public.guild_rule_set_configs (
    set_id     bigint      not null primary key references app_public.guild_rule_sets on delete cascade,
    -- whether or not the associated **global** rule_set is enabled
    enabled    boolean     not null,
    config     json        not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

drop table if exists app_public.guild_rules cascade;
create table app_public.guild_rules (
    id         bigint      not null primary key default pseudo_encrypt(nextval('app_public.guild_rule_ids')::bigint),
    set_id     bigint      not null references app_public.guild_rule_sets on delete cascade,
    name       text        not null,
    enabled    boolean     not null,
    trigger    jsonb       not null,
    conditions jsonb       not null,
    actions    jsonb       not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index on app_public.guild_rule_sets(guild_id);
create index on app_public.guild_rule_set_configs(set_id);
create index on app_public.guild_rules(set_id);

alter table app_public.guild_rule_sets        enable row level security;
alter table app_public.guild_rule_set_configs enable row level security;
alter table app_public.guild_rules            enable row level security;

-- all since users should be able to select, insert, update, delete these
create policy select_managed_guild_rule_sets on app_public.guild_rule_sets
  for all using (guild_id in (select app_public.current_user_managed_guild_ids()));

create policy select_managed_guild_rule_set_configs on app_public.guild_rule_set_configs
  for all using (set_id in (
    select set_id
      from app_public.guild_rule_sets
     where guild_id in (select app_public.current_user_managed_guild_ids())));

create policy select_managed_guild_rules on app_public.guild_rules
  for all using (set_id in (
    select set_id
      from app_public.guild_rule_sets
     where guild_id in (select app_public.current_user_managed_guild_ids())));

grant select, delete, insert(
    guild_id, name, description, enabled, category
), update(
    name, description, enabled, category
) on app_public.guild_rule_sets to :DATABASE_VISITOR;

grant select, delete, insert(
    set_id, enabled, config
), update(
    enabled, config
) on app_public.guild_rule_set_configs to :DATABASE_VISITOR;

grant select, delete, insert(
    set_id, name, enabled, trigger, conditions, actions
), update(
    name, enabled, trigger, conditions, actions
) on app_public.guild_rules     to :DATABASE_VISITOR;

-- created_at/updated_at triggers
create trigger _100_timestamps
  before insert or update on app_public.guild_rule_sets
  for each row
  execute procedure app_private.tg__timestamps();

create trigger _100_timestamps
  before insert or update on app_public.guild_rule_set_configs
  for each row
  execute procedure app_private.tg__timestamps();

create trigger _100_timestamps
  before insert or update on app_public.guild_rules
  for each row
  execute procedure app_private.tg__timestamps();

-- 

drop type if exists app_public.rule_scope cascade;
create type app_public.rule_scope as enum(
    'GUILD',
    'CHANNEL',
    'USER'
);

-- This is shown as "counter" in UI / other parts of sushii
-- but really it's a gauge since it can decrease
drop table if exists app_public.rule_gauges cascade;
create table app_public.rule_gauges (
    time      timestamptz           not null,
    -- gauges unique to each guild
    guild_id  bigint                not null,
    -- which guild/channel/user to keep these counts to
    -- can't just use scope_id since I think the default guild channel ID is same as guild id
    scope     app_public.rule_scope not null,
    -- id of actual guild/channel/user
    scope_id  bigint                not null,
    -- name of gauge
    name      text                  not null,
    -- current value of gauge
    value     bigint                not null,
    primary key (time, guild_id, scope, scope_id, name)
);

-- timescale hypertable
select create_hypertable('app_public.rule_gauges', 'time');
-- Delete data older than 6 months, shouldn't be very much data but I guess we'll see
select add_retention_policy('app_public.rule_gauges', INTERVAL '6 months');
create index on app_public.rule_gauges(guild_id, scope, scope_id, name, time DESC);

-- Where rules can save data to
drop table if exists app_public.rule_persistence cascade;
create table app_public.rule_persistence (
    -- 0 if global data, with scope as user
    guild_id  bigint                not null,
    scope     app_public.rule_scope not null,
    scope_id  bigint                not null,
    data      jsonb                 not null,
    primary key (guild_id, scope, scope_id)
);
