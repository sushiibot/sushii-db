drop table if exists app_public.guild_feeds cascade;
create table app_public.guild_feeds (
    guild_id      BIGINT NOT NULL,
    channel_id    BIGINT NOT NULL,
    mention_role  BIGINT,
    -- name to display to user
    feed_name     TEXT   NOT NULL,
    -- original source url, e.g. twitter.com
    feed_source   TEXT   NOT NULL,
    -- feed ID should comprise of the feed type in addition to parameters,
    -- eg. same youtube feed type but for multiple different channels
    feed_hash     TEXT   GENERATED
        ALWAYS AS (encode(
            sha256(feed_source::bytea || feed_metadata::text::bytea), 'hex'
        )) STORED,
    -- contains args and query params
    feed_metadata JSONB  NOT NULL,
    PRIMARY KEY (feed_hash, channel_id)
);

create index on app_public.guild_feeds(guild_id);

alter table app_public.guild_feeds enable row level security;
drop policy if exists select_managed on app_public.guild_feeds;
create policy select_managed on app_public.guild_feeds
  for select using (id in (select app_public.current_user_managed_guild_ids()));
create policy update_managed on app_public.guild_feeds
  for update using (id in (select app_public.current_user_managed_guild_ids()));

grant select on app_public.guild_feeds to :DATABASE_VISITOR;

-- disable getting all at once, only allow getting by id
comment on table app_public.cached_guilds is E'@omit all,filter';
