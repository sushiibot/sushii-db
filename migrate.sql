BEGIN;

-- SERVER CONFIGS
INSERT INTO app_public.guild_configs (
        id,
        prefix,
        join_msg,
        join_react,
        leave_msg,
        msg_channel,
        role_channel,
        role_config,
        invite_guard,
        log_msg,
        log_mod,
        log_member,
        mute_role,
        max_mention,
        disabled_channels
    )
SELECT id,
    prefix,
    join_msg,
    join_react,
    leave_msg,
    msg_channel,
    role_channel,
    role_config,
    invite_guard,
    log_msg,
    log_mod,
    log_member,
    mute_role,
    max_mention,
    disabled_channels
FROM sushii_2.guild_configs;

INSERT INTO app_public.guild_configs (
        id,
        prefix,
        join_msg,
        join_react,
        leave_msg,
        msg_channel,
        role_channel,
        role_config,
        invite_guard,
        log_msg,
        log_mod,
        log_member,
        mute_role,
        max_mention,
        disabled_channels
    )
SELECT id,
    prefix,
    join_msg,
    join_react,
    leave_msg,
    msg_channel,
    role_channel,
    role_config,
    invite_guard,
    log_msg,
    log_mod,
    log_member,
    mute_role,
    max_mention,
    disabled_channels
FROM sushii_old.guilds ON CONFLICT DO NOTHING;

-- SERVER TAGS
-- add new tags
INSERT INTO app_public.tags (
        owner_id,
        guild_id,
        tag_name,
        content,
        use_count,
        created
    )
SELECT owner_id,
    guild_id,
    tag_name,
    content,
    use_count,
    created
FROM sushii_2.tags;

-- add old tag tags that don't conflict
INSERT INTO app_public.tags (
        owner_id,
        guild_id,
        tag_name,
        content,
        use_count,
        created
    )
SELECT owner_id,
    guild_id,
    tag_name,
    content,
    count,
    created
FROM sushii_old.tags ON CONFLICT (guild_id, tag_name) DO NOTHING;

-- add the conflicting tags
do
$$
declare
    f record;
    num int;
begin
    for f in select sushii_old.tags.*
               from sushii_old.tags, sushii_2.tags
              where sushii_old.tags.tag_name = sushii_2.tags.tag_name
                and sushii_old.tags.guild_id = sushii_2.tags.guild_id
    loop
        num := 0;

        -- try adding tag with oldn appended
        loop
            -- if there is already a tag with oldn appended
            IF EXISTS (
                select sushii_old.tags.*
                  from sushii_old.tags, sushii_2.tags
                 where sushii_old.tags.tag_name = sushii_2.tags.tag_name || 'old' || num
                   and sushii_old.tags.guild_id = sushii_2.tags.guild_id
            ) THEN
                -- inc count
                num = num + 1;
            ELSE
                -- if there isn't one, can add now
                INSERT INTO app_public.tags
                        VALUES (f.owner_id,
                                f.guild_id,
                                f.tag_name || 'old' || num,
                                f.content,
                                f.count,
                                f.created);
            END IF;
        end loop;
    end loop;
end
$$;

-- USER DATA (fishies, rep, etc)
INSERT INTO app_public.users (
        id,
        is_patron,
        patron_emoji,
        rep,
        fishies,
        last_rep,
        last_fishies,
        profile_data,
        lastfm_username
    )
SELECT id,
    is_patron,
    patron_emoji,
    rep,
    fishies,
    last_rep,
    last_fishies,
    profile_options,
    lastfm
FROM sushii_old.users;

INSERT INTO app_public.users (
                id,
                is_patron,
                patron_emoji,
                rep,
                fishies,
                last_rep,
                last_fishies,
                profile_data,
                lastfm_username
            )
SELECT id,
       is_patron,
       patron_emoji,
       rep,
       fishies,
       last_rep,
       last_fishies,
       profile_data,
       lastfm_username
  FROM sushii_2.users ON CONFLICT (id) DO UPDATE
   SET fishies         = app_public.users.fishies + excluded.fishies,
       rep             = app_public.users.rep     + excluded.rep,
       is_patron       = excluded.is_patron,
       lastfm_username = excluded.lastfm_username;


-- USER LEVELS 
SELECT 'user_levels sushii2 before',
       COUNT(*)
  FROM app_public.user_levels;

SELECT 'sushiidev.levels before',
       COUNT(*)
  FROM sushii_old.levels;

INSERT INTO app_public.user_levels (
        user_id,
        guild_id,
        msg_all_time,
        msg_month,
        msg_week,
        msg_day,
        last_msg
    )
SELECT user_id,
       guild_id,
       msg_all_time,
       msg_month,
       msg_week,
       msg_day,
       last_msg
  FROM sushii_old.levels
       ON CONFLICT (user_id, guild_id) DO
       UPDATE
         SET msg_all_time = excluded.msg_all_time,
             msg_month    = excluded.msg_month,
             msg_week     = excluded.msg_week,
             msg_day      = excluded.msg_day,
             last_msg     = excluded.last_msg;
-- ignore sushii2 levels

SELECT 'user_levels sushii2 after',
       COUNT(*)
  FROM app_public.user_levels;




-- REMINDERS

INSERT INTO app_public.reminders (
                user_id,
                description,
                set_at,
                expire_at
            )
SELECT user_id,
       description,
       time_set,
       time_to_remind
FROM sushii_old.reminders;


INSERT INTO app_public.reminders (
                user_id,
                description,
                set_at,
                expire_at
            )
SELECT user_id,
       description,
       set_at,
       expire_at
FROM sushii_2.reminders;


-- VLIVE notifs
INSERT INTO app_public.feeds (
                feed_id
            )
SELECT 'vlive:videos:' || channel_code
  FROM sushii_old.vlive_channels
 GROUP BY channel_code;

INSERT INTO app_public.feed_subscriptions (
                feed_id,
                guild_id,
                channel_id,
                mention_role
            )
SELECT 'vlive:videos:' || channel_code, -- feed ID
       guild_id,
       discord_channel,
       mention_role
  FROM sushii_old.vlive_channels;

COMMIT;
