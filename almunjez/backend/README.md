# AlMunjez backend

```
backend/
├── schema/001_initial.sql       # the whole data model, authorization and write API (doc 04, 06, 07, 09)
└── tests/
    ├── _stub_auth.sql           # auth.uid() stand-in for plain Postgres — never apply to Supabase
    ├── smoke.sql                # rule-by-rule assertions
    ├── claim_concurrency.sh     # N parallel claimers → exactly one winner
    └── run.sh                   # recreate DB, apply, run everything
```

## Run the tests locally

Needs a local Postgres 15+ you can create databases on (a scratch cluster, `supabase start`'s
database, or Docker). Never point this at a real Supabase project: the stub replaces `auth.uid()`.

```bash
export PGHOST=localhost PGPORT=5432 PGUSER=postgres
backend/tests/run.sh          # smoke + 40-way claim race
backend/tests/run.sh 100      # bigger race
```

Expected tail of the output:

```
smoke: all assertions passed
claimers=40 wins=1 already_claimed=39
claim_concurrency: PASS
```

## Apply to Supabase

```bash
supabase db push            # or: psql "$SUPABASE_DB_URL" -f backend/schema/001_initial.sql
psql "$SUPABASE_DB_URL" -f backend/schema/003_storage.sql   # private `task-files` bucket + policies (proof photos)
```

`003_storage.sql` also runs from the dashboard's SQL Editor. It creates the `task-files`
bucket (30 MB, jpeg/png/heic/pdf) and RLS on `storage.objects` that mirrors `can_view_task`
from the object path alone, so members see their group's files and personal files stay
private; `tests/storage.sql` asserts exactly that.

The file detects `auth.users`, `pg_cron`, and the `authenticated`/`anon` roles and wires the
trigger, schedules and grants only when they exist, so the same file runs in both environments.
