#!/usr/bin/env bash
# Create the MAIA database roles and the baseline privilege model.
#
# Executed once by the postgres entrypoint, on first initialization of an empty
# data directory, after the image's 10_postgis.sh.
#
# Roles:
#   migrator  owns the database and its schema; runs Alembic migrations (DDL).
#   app       used by the API; SELECT/INSERT/UPDATE on tables only. No DELETE
#             (soft delete only) and no TRUNCATE. Restrictions on audit_log are
#             applied by its migration.
#   audit     used for audit chain verification; receives no table privileges
#             here, they are granted by the audit_log migration.
set -euo pipefail

psql -v ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    -v db_name="$POSTGRES_DB" \
    -v migrator_user="$MAIA_DB_MIGRATOR_USER" \
    -v migrator_password="$MAIA_DB_MIGRATOR_PASSWORD" \
    -v app_user="$MAIA_DB_APP_USER" \
    -v app_password="$MAIA_DB_APP_PASSWORD" \
    -v audit_user="$MAIA_DB_AUDIT_USER" \
    -v audit_password="$MAIA_DB_AUDIT_PASSWORD" <<'SQL'
CREATE ROLE :"migrator_user" LOGIN PASSWORD :'migrator_password'
    NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE ROLE :"app_user" LOGIN PASSWORD :'app_password'
    NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE ROLE :"audit_user" LOGIN PASSWORD :'audit_password'
    NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;

-- The database owner also owns the public schema (pg_database_owner, PG 15+).
ALTER DATABASE :"db_name" OWNER TO :"migrator_user";

REVOKE ALL ON DATABASE :"db_name" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"db_name" TO :"migrator_user", :"app_user", :"audit_user";

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO :"app_user", :"audit_user";

-- Privileges on every table and sequence the migrator creates from now on.
ALTER DEFAULT PRIVILEGES FOR ROLE :"migrator_user" IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO :"app_user";
ALTER DEFAULT PRIVILEGES FOR ROLE :"migrator_user" IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO :"app_user";
SQL
