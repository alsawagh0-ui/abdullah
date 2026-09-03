#!/usr/bin/env bash
# Recreate the test database, apply stub + schema, run smoke test and the claim race.
# Requires PGHOST/PGPORT/PGUSER pointing at a local Postgres 15+ (never a Supabase project).
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${PGDATABASE:-almunjez_test}; export PGDATABASE=postgres
dropdb --if-exists "$DB" && createdb "$DB"
export PGDATABASE="$DB"
psql -v ON_ERROR_STOP=1 -q -f tests/_stub_auth.sql
psql -v ON_ERROR_STOP=1 -q -f schema/001_initial.sql && echo "schema: applied"
psql -v ON_ERROR_STOP=1 -q -f tests/smoke.sql 2>&1 | grep -E '^(NOTICE|psql|ERROR|smoke)' | sed 's/^NOTICE:  //'
tests/claim_concurrency.sh "${1:-40}"
