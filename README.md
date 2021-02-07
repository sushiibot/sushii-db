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
