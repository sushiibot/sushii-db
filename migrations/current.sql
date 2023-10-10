-- lookup groups -- make lookups private within groups

drop table if exists app_public.lookup_groups cascade;
drop table if exists app_public.lookup_group_members cascade;
drop table if exists app_public.lookup_group_invites cascade;

create table app_public.lookup_groups (
  -- For referencing in lists
  id          serial unique,

  guild_id    bigint not null, -- owner guild
  name        text not null,

  creator_id  bigint not null, -- group creator for contact/tracking purposes
  description text,

  -- guilds can have any number of groups but they must have unique names
  primary key (guild_id, name)
);

-- guilds that are part of the group
create table app_public.lookup_group_members (
  owner_guild_id bigint not null,
  name           text   not null,

  -- member of group
  member_guild_id bigint not null,

  foreign key (owner_guild_id, name) references app_public.lookup_groups(guild_id, name) on delete cascade,
  primary key (owner_guild_id, name)
);

-- to join a group, owner creates an invite code
create table app_public.lookup_group_invites (
  owner_guild_id bigint not null,
  name           text   not null,

  invite_code text        not null unique,
  expires_at  timestamptz,

  foreign key (owner_guild_id, name) references app_public.lookup_groups(guild_id, name) on delete cascade,

  -- 1 invite code per group per guild
  primary key (owner_guild_id, name)
)
