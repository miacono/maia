#!/usr/bin/env bash
# Wait until PostgreSQL accepts TCP connections, or fail after a timeout.
#
# Usage: wait-for-db.sh [host] [port] [timeout_seconds]
# Defaults come from DB_HOST, DB_PORT and DB_WAIT_TIMEOUT, then
# localhost, 5432 and 60.
#
# Uses pg_isready when available; otherwise falls back to a plain TCP check.
set -euo pipefail

host="${1:-${DB_HOST:-localhost}}"
port="${2:-${DB_PORT:-5432}}"
timeout="${3:-${DB_WAIT_TIMEOUT:-60}}"

is_ready() {
    if command -v pg_isready >/dev/null 2>&1; then
        pg_isready -q -h "$host" -p "$port"
    else
        (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null
    fi
}

deadline=$((SECONDS + timeout))
until is_ready; do
    if ((SECONDS >= deadline)); then
        echo "wait-for-db: ${host}:${port} not ready after ${timeout}s" >&2
        exit 1
    fi
    sleep 1
done
echo "wait-for-db: ${host}:${port} is ready"
