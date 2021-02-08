
-- psql -f pub.backup.sql
-- revert back to default sushii2 schema
SET SEARCH_PATH TO DEFAULT;
--
-- SERVER CONFIGS
INSERT INTO app_public.guild_configs (
        id,
        name,
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
        max_mention
    )
SELECT id,
    name,
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
    disabled_channels -- TODO
FROM sushiidev.guild_configs ON CONFLICT DO NOTHING;
-- SERVER TAGS
-- append 'old' to conflict tags
UPDATE TABLE tags
SET public.tag_name = public.tag_name || 'old'
FROM public.tags,
    sushiidev.tags
WHERE public.tag_name = sushiidev.tag_name
    AND public.guild_id = sushiidev.guild_id;
-- add old tags
INSERT INTO tags (
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
FROM sushiidev.tags ON CONFLICT (guild_id, tag_name) DO NOTHING;
-- USER DATA (fishies, rep, etc)
INSERT INTO users (
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
FROM sushiidev.users ON CONFLICT (id) DO
UPDATE
SET public.users.fishies = public.users.fishies + sushiidev.fishies,
    public.users.rep = public.users.rep + sushiidev.rep,
    is_patron = is_patron,
    lastfm_username = lastfm;
-- USER LEVELS 
SELECT 'user_levels sushii2 before',
    COUNT(*)
FROM user_levels;
SELECT 'sushiidev.levels before',
    COUNT(*)
FROM sushiidev.levels;
INSERT INTO user_levels (
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
FROM sushiidev.levels ON CONFLICT (user_id, guild_id) DO
UPDATE
SET msg_all_time = msg_all_time,
    msg_month = msg_month,
    msg_week = msg_week,
    msg_day = msg_day,
    last_msg = last_msg;
SELECT 'user_levels sushii2 after',
    COUNT(*)
FROM user_levels;
COMMIT;
-- REMINDERS
INSERT INTO reminders (
        user_id,
        channel_id,
        description,
        set_at,
        expire_at
    )
SELECT user_id,
    description,
    time_set,
    time_to_remind
FROM sushiidev.reminders;