# sushii-db

sushii database migrations and database setup.

## Requirements

* `postgresql-client` for `pg_dump` (TODO: Use the `pg_dump` in the pg docker container)

## Setup

1. Add roles and databases.
    ```bash
    # If in docker container
    docker exec -it container_id /bin/bash

    createuser --pwprompt sushii
    createuser --pwprompt sushii_visitor

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
   drop schema if exists sushii_old;
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
   psql -U sushii -W -h localhost -d sushii_shadow -f sushii_2.sql
   psql -U sushii -W -h localhost -d sushii_shadow -f sushii_old_copy.sql
   ```
5. Run `migrate.sql` to merge data
   ```bash
   yarn gm run --shadow migrate.sql
   ```

## Deployment

1. Update sushii2 to run any pending migrations in prod
2. Dump databases to sql files above
3. Create new db (separate docker service to preserve previous sushii2 db)
4. Add sushii2 / sushiiold data above
5. Run `migrate.sql` -- sushii should NOT be running, `yarn reset` if not empty
6. Update `.env` to use primary token, create `.env_old` for sushii2 token
7. **Remove sqlx embedded migrations in sushii-2 before connecting to new db**
8. Create new sushii docker service with sushiiDev token to replace sushiiDev but keep sushii2 running
9. Update avatar / username
