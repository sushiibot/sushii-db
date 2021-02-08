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
2. `yarn run raphile-migrate init`
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
      --inserts \
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
      --inserts \
      sushii2 > /root/sushii_2.sql

   # remove public schema name
   sed -i -e 's/public\./sushii_2\./' postgres_root/sushii_2.sql
   ```
2. Add temp schema
   ```sql
   drop schema if exists sushii_old;
   create schema sushii_old;
   ```

1. Delete extra settings and stuff on top
2. Run dumped file
   ```bash
   yarn gm run --shadow sushii_2.sql
   ```
3. Repeat with sushii_2 data
4. Run `migrate.sql` to merge data
   ```bash
   yarn gm run --shadow migrate.sql
   ```
