# sushii-db

sushii database migrations and database setup.

## Requirements

* `postgresql-client` for `pg_dump`
  * Or just use `pg_dump` in the pg docker container and `docker cp` the file out

## Setup

1. Add roles and databases.
    ```bash
    # If in docker container
    docker exec -it container_id /bin/bash

    createuser --pwprompt sushii
    createuser --pwprompt sushii_visitor
    createuser --pwprompt sushii_authenticator

    createdb sushii --owner=sushii

    # only required in local dev
    createdb sushii_shadow --owner=sushii
    ```
2. `yarn run graphile-migrate init`
3. Source .env file and run
    ```bash
    . ./.env
    graphile-migrate watch
    ```

## sushii-bot to sushii2 data migration

1. pg_dump plain text for **both** sushii-bot and sushii2
   ```bash
   # sushii-bot
   pg_dump \
      --format=p \
      --no-owner \
      --schema=public \
      --table=guilds \
      --table=levels \
      --table=member_events \
      --table=mod_log \
      --table=mutes \
      --table=reminders \
      --table=tags \
      --table=users \
      --table=vlive_channels \
      sushii > ./sushii_old.sql

   # sushii-2
   pg_dump \
      --format=p \
      --no-owner \
      --schema=public \
      --exclude-table=_sqlx_migrations \
      --exclude-table=cached_users \
      --exclude-table=cached_guilds \
      --exclude-table=messages \
      -U drk \
      sushii2 > /root/sushii_2.sql

   # remove public schema name
   sed -i -e 's/public\./sushii_2\./g' sushii_2.sql
   sed -i -e 's/public\./sushii_old\./g' sushii_old.sql
   ```
2. Add temp schema
   ```sql
   drop schema if exists sushii_old cascade;
   create schema sushii_old;
   ```
3. Delete extra settings and stuff on top
   ```sql
   drop schema if exists sushii_2 cascade;
   create schema sushii_2;
   ```
4. Add sushii-2 and sushii-old dumped data
   ```bash
   # use psql since using graphile-migrate runs out of memory for big dump
   # and requires --inserts format which slows things down a LOT
   psql -U sushii -W -h 172.19.0.3 -d sushii -f sushii_2.sql
   psql -U sushii -W -h 172.19.0.3 -d sushii -f sushii_old_copy.sql
   ```
5. Run `migrate.sql` to merge data
   ```bash
   psql migrate.sql
   ```

## Deployment

1. [x] Update sushii2 to run any pending migrations in prod
2. [x] Dump databases to sql files above
3. [x] Create new db (separate docker service to preserve previous sushii2 db)
4. [x] Add sushii2 / sushiiold data above
5. [x] Run `migrate.sql` -- sushii should NOT be running, `yarn reset` if not empty
6. [x] Update `.env` to use primary token, create `.env_old` for sushii2 token
7. [x] **Remove sqlx embedded migrations in sushii-2 before connecting to new db**
8. [x] Create new sushii docker service with sushiiDev token to replace sushiiDev but keep sushii2 running
9. [ ] Update avatar / username

## postgraphile support

Need to create sushii_authenticator role for postgraphile, requires admin role to
grant permissions but we can't use `afterReset.sql` since

```sql
-- This is the no-access role that PostGraphile will run as by default, allow connecting
GRANT CONNECT ON DATABASE :DATABASE_NAME TO :DATABASE_AUTHENTICATOR;
-- Enables authenticator to switch to visitor role
GRANT :DATABASE_VISITOR TO :DATABASE_AUTHENTICATOR;

-- enable uuids
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
```
