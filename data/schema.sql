--
-- PostgreSQL database dump
--

-- Dumped from database version 12.4 (Debian 12.4-1.pgdg100+1)
-- Dumped by pg_dump version 12.5 (Ubuntu 12.5-0ubuntu0.20.04.1)

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

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: cached_guilds; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.cached_guilds (
    id bigint NOT NULL,
    name text NOT NULL,
    member_count bigint NOT NULL,
    icon_url text,
    features text NOT NULL,
    splash_url text,
    banner_url text
);


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
-- Name: cached_guilds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cached_guilds (
    id bigint NOT NULL,
    name text NOT NULL,
    member_count bigint NOT NULL,
    icon_url text,
    features text NOT NULL,
    splash_url text,
    banner_url text
);


--
-- Name: cached_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cached_users (
    id bigint NOT NULL,
    avatar_url text NOT NULL,
    name text NOT NULL,
    discriminator integer NOT NULL,
    last_checked timestamp without time zone NOT NULL
);


--
-- Name: feed_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_items (
    feed_id text NOT NULL,
    item_id text NOT NULL
);


--
-- Name: feed_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_subscriptions (
    feed_id text NOT NULL,
    guild_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    mention_role bigint
);


--
-- Name: feeds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feeds (
    feed_id text NOT NULL,
    metadata jsonb
);


--
-- Name: guild_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guild_configs (
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
-- Name: members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.members (
    guild_id bigint NOT NULL,
    user_id bigint NOT NULL,
    join_time timestamp without time zone NOT NULL
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    message_id bigint NOT NULL,
    author_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    created timestamp without time zone NOT NULL,
    content text NOT NULL,
    msg jsonb NOT NULL
);


--
-- Name: mod_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mod_logs (
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
-- Name: mutes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mutes (
    guild_id bigint NOT NULL,
    user_id bigint NOT NULL,
    start_time timestamp without time zone NOT NULL,
    end_time timestamp without time zone,
    pending boolean DEFAULT false NOT NULL,
    case_id bigint
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    user_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    keyword text NOT NULL
);


--
-- Name: reminders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reminders (
    user_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    description text NOT NULL,
    set_at timestamp without time zone NOT NULL,
    expire_at timestamp without time zone NOT NULL
);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    owner_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    tag_name text NOT NULL,
    content text NOT NULL,
    use_count bigint NOT NULL,
    created timestamp without time zone NOT NULL
);


--
-- Name: user_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_levels (
    user_id bigint NOT NULL,
    guild_id bigint NOT NULL,
    msg_all_time bigint NOT NULL,
    msg_month bigint NOT NULL,
    msg_week bigint NOT NULL,
    msg_day bigint NOT NULL,
    last_msg timestamp without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
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
-- Name: cached_guilds cached_guilds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cached_guilds
    ADD CONSTRAINT cached_guilds_pkey PRIMARY KEY (id);


--
-- Name: cached_users cached_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cached_users
    ADD CONSTRAINT cached_users_pkey PRIMARY KEY (id);


--
-- Name: feed_items feed_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_items
    ADD CONSTRAINT feed_items_pkey PRIMARY KEY (feed_id, item_id);


--
-- Name: feed_subscriptions feed_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_subscriptions
    ADD CONSTRAINT feed_subscriptions_pkey PRIMARY KEY (feed_id, channel_id);


--
-- Name: feeds feeds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feeds
    ADD CONSTRAINT feeds_pkey PRIMARY KEY (feed_id);


--
-- Name: guild_configs guild_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guild_configs
    ADD CONSTRAINT guild_configs_pkey PRIMARY KEY (id);


--
-- Name: members members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pkey PRIMARY KEY (guild_id, user_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (message_id);


--
-- Name: mod_logs mod_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mod_logs
    ADD CONSTRAINT mod_logs_pkey PRIMARY KEY (guild_id, case_id);


--
-- Name: mutes mutes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mutes
    ADD CONSTRAINT mutes_pkey PRIMARY KEY (guild_id, user_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (user_id, guild_id, keyword);


--
-- Name: reminders reminders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reminders
    ADD CONSTRAINT reminders_pkey PRIMARY KEY (user_id, set_at);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (guild_id, tag_name);


--
-- Name: user_levels user_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_levels
    ADD CONSTRAINT user_levels_pkey PRIMARY KEY (user_id, guild_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


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

CREATE INDEX tag_name_idx ON app_public.tags USING gin (tag_name gin_trgm_ops);


--
-- Name: notification_guild_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_guild_id_idx ON public.notifications USING btree (guild_id);


--
-- Name: notification_keyword_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_keyword_idx ON public.notifications USING btree (keyword);


--
-- Name: tag_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tag_name_idx ON public.tags USING gin (tag_name gin_trgm_ops);


--
-- Name: feed_items fk_feed_item_feed_id; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.feed_items
    ADD CONSTRAINT fk_feed_item_feed_id FOREIGN KEY (feed_id) REFERENCES app_public.feeds(feed_id) ON DELETE CASCADE;


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
-- Name: feed_items fk_feed_item_feed_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_items
    ADD CONSTRAINT fk_feed_item_feed_id FOREIGN KEY (feed_id) REFERENCES public.feeds(feed_id) ON DELETE CASCADE;


--
-- Name: feed_subscriptions fk_feed_subscription_feed_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_subscriptions
    ADD CONSTRAINT fk_feed_subscription_feed_id FOREIGN KEY (feed_id) REFERENCES public.feeds(feed_id) ON DELETE CASCADE;


--
-- Name: mutes fk_mod_action; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mutes
    ADD CONSTRAINT fk_mod_action FOREIGN KEY (guild_id, case_id) REFERENCES public.mod_logs(guild_id, case_id);


--
-- Name: SCHEMA app_hidden; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA app_hidden TO sushii_visitor;


--
-- Name: SCHEMA app_public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA app_public TO sushii_visitor;


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

