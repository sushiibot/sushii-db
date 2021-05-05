drop table if exists app_public.guild_rule_sets cascade;
create table app_public.guild_rule_sets (
    id          uuid    not null primary key,
    guild_id    bigint  not null references app_public.cached_guilds on delete cascade,
    name        text    not null,
    description text,
    enabled     boolean not null,
    editable    boolean not null,
    author      bigint,
    category    text,
    config      json,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

drop table if exists app_public.guild_rules cascade;
create table app_public.guild_rules (
    id         uuid    not null primary key,
    set_id     uuid    not null references app_public.guild_rule_sets on delete cascade,
    guild_id   bigint  not null references app_public.cached_guilds   on delete cascade,
    name       text    not null,
    enabled    boolean not null,
    trigger    jsonb,
    conditions jsonb,
    actions    jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index on app_public.guild_rule_sets(guild_id);
create index on app_public.guild_rules(guild_id);
create index on app_public.guild_rules(set_id);

alter table app_public.guild_rule_sets enable row level security;
alter table app_public.guild_rules     enable row level security;

-- all since users should be able to select, insert, update, delete these
create policy select_managed_guild_rules on app_public.guild_rule_sets
  for all using (guild_id in (select app_public.current_user_managed_guild_ids()));
create policy select_managed_guild_rules on app_public.guild_rules
  for all using (guild_id in (select app_public.current_user_managed_guild_ids()));

grant select, update(
    name, description, enabled, category, config
) on app_public.guild_rule_sets to :DATABASE_VISITOR;
grant select, update(
    name, enabled, trigger, conditions, actions
) on app_public.guild_rules     to :DATABASE_VISITOR;

-- created_at/updated_at triggers
create trigger _100_timestamps
  before insert or update on app_public.guild_rule_sets
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
