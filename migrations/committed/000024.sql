--! Previous: sha1:2f9816dd4b2fe8fa9f870299a3215ae46e699dbd
--! Hash: sha1:64c0d5a6558c77ea4d89484eabdbd6f60f9afb40

-- Enter migration here

alter table app_public.guild_configs
    drop column if exists mute_role,
    drop column if exists mute_duration,
    drop column if exists max_mention,
    drop column if exists invite_guard;
