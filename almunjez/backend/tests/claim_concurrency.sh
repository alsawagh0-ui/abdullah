#!/usr/bin/env bash
# N parallel sessions call claim_task on one open task; exactly one must win.
# Usage: PGHOST=... PGPORT=... PGUSER=... PGDATABASE=... tests/claim_concurrency.sh [N]
set -euo pipefail
N=${1:-40}
psql -v ON_ERROR_STOP=1 -q <<SQL
insert into users (id, display_name) select gen_random_uuid(), 'racer ' || i from generate_series(1, $((N+1))) i
 where not exists (select 1 from users where display_name = 'racer ' || i);
SQL
CREATOR=$(psql -Atc "select id from users where display_name = 'racer 1'")
G=$(psql -Atc "select set_config('app.uid', '$CREATOR', false); select create_group('سباق', 'team') ->> 'group_id'" | tail -1)
CODE=$(psql -Atc "select code from group_invites where group_id = '$G' and revoked_at is null")
# everyone joins and is accepted
psql -v ON_ERROR_STOP=1 -q <<SQL
do \$\$ declare u record; r join_requests;
begin
  for u in select id from users where display_name like 'racer %' and id <> '$CREATOR' loop
    perform set_config('app.uid', u.id::text, true);
    r := request_join('$CODE');
    perform set_config('app.uid', '$CREATOR', true);
    perform decide_join(r.id, true);
  end loop;
end \$\$;
SQL
TASK=$(psql -Atc "select set_config('app.uid', '$CREATOR', false); select (create_task('من يتولاها؟', '$G')).id" | tail -1)
mapfile -t USERS < <(psql -Atc "select id from users where display_name like 'racer %' and id <> '$CREATOR' limit $N")
OUT=$(mktemp)
for u in "${USERS[@]}"; do
  ( psql -Atq -c "select set_config('app.uid', '$u', false); select 'WIN' from claim_task('$TASK')" 2>&1 | grep -E 'WIN|already_claimed|ERROR' | head -1 ) >> "$OUT" &
done
wait
WINS=$(grep -c WIN "$OUT" || true); LOSSES=$(grep -c already_claimed "$OUT" || true); OTHER=$(grep -c ERROR "$OUT" | grep -v already_claimed || true)
echo "claimers=$N wins=$WINS already_claimed=$LOSSES"
ASSIGNEE=$(psql -Atc "select assignee_id from tasks where id = '$TASK'")
EVENTS=$(psql -Atc "select count(*) from activity_events where target_id = '$TASK' and action = 'task.claimed'")
echo "assignee=$ASSIGNEE claimed_events=$EVENTS"
[[ "$WINS" == "1" && "$LOSSES" == "$((N-1))" && "$EVENTS" == "1" ]] && echo "claim_concurrency: PASS" || { echo "claim_concurrency: FAIL"; cat "$OUT"; exit 1; }
