MATRIX_OUT=${MATRIX_OUT:-$PWD/matrix-evidence}
MATRIX_TAG=${MATRIX_TAG:-agro-matrix}
STATE_DIR="$MATRIX_OUT/.state"
CONSOLE_URL=${CONSOLE_URL:-http://127.0.0.1:3005}
CONSOLE_SPEC=${CONSOLE_SPEC:-n4}
mkdir -p "$MATRIX_OUT" "$STATE_DIR"

now() { date +%s.%N | cut -c1-14; }
elapsed() { awk "BEGIN{printf \"%.1f\", $2-$1}"; }
SSHO=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o LogLevel=ERROR -o UserKnownHostsFile="$STATE_DIR/known_hosts")

vercel_preflight() { : "${VERCEL_SCOPE:?set VERCEL_SCOPE to the Vercel team slug}"; vercel whoami >/dev/null 2>&1 && vercel sandbox list --scope "$VERCEL_SCOPE" >/dev/null 2>&1; }
vercel_create() { vercel sandbox create --scope "$VERCEL_SCOPE" --name "$1" --vcpus 2 --timeout 42m --non-persistent --tag "purpose=$MATRIX_TAG" 2>&1 | tail -2; }
vercel_exec() { local n=$1; shift; vercel sandbox exec "$n" --scope "$VERCEL_SCOPE" --timeout 2m -- bash -c "$*" 2>/dev/null | grep -v '^\$ \|^Vercel CLI'; return "${PIPESTATUS[0]}"; }
vercel_destroy() { vercel sandbox remove "$1" --scope "$VERCEL_SCOPE" 2>&1 | tail -1; }
vercel_list() { vercel sandbox list --scope "$VERCEL_SCOPE" 2>&1 | grep -c "purpose=$MATRIX_TAG" || true; }

exedev_preflight() { timeout 30 ssh "${SSHO[@]}" exe.dev whoami --json >/dev/null; }
exedev_create() { local img=(); [ -n "${IMAGE:-}" ] && img=(--image "$IMAGE"); timeout 300 ssh "${SSHO[@]}" exe.dev new --json --name "$1" --tag "$MATRIX_TAG" "${img[@]}"; }
exedev_exec() { local n=$1; shift; timeout 120 ssh "${SSHO[@]}" "$n.exe.xyz" "$*"; }
exedev_destroy() { timeout 120 ssh "${SSHO[@]}" exe.dev rm "$1" 2>&1 | tail -1; }
exedev_restart() { timeout 180 ssh "${SSHO[@]}" exe.dev restart "$1" 2>&1 | tail -1; }
exedev_list() { timeout 60 ssh "${SSHO[@]}" exe.dev ls --json | python3 -c "import json,sys; print(sum('$MATRIX_TAG' in (v.get('tags') or []) for v in json.load(sys.stdin)['vms']))"; }
exedev_https_url() { echo "https://$1.exe.xyz/"; }

capi() {
  : "${CONSOLE_DIR:?set CONSOLE_DIR to the agro-console checkout}"
  ( cd "$CONSOLE_DIR" && node_modules/.bin/dotenv $(sh scripts/agro-env.sh --dotenv) -- bash -c '
    args=(-sS -X "$1" -H "x-provision-key: $PROVISION_KEY" -H "content-type: application/json")
    [ -n "${3:-}" ] && args+=(-d "$3")
    curl "${args[@]}" "$4$2"' _ "$1" "$2" "${3:-}" "$CONSOLE_URL" )
}
console_preflight() { : "${CONSOLE_SSH_KEY:?set CONSOLE_SSH_KEY to the private key path}" "${CONSOLE_SSH_KEY_ID:?set CONSOLE_SSH_KEY_ID to the registered console key id}"; capi GET /api/nodes | jq -e '.nodes' >/dev/null; }
console_ssh() { local n=$1; shift; timeout 120 ssh "${SSHO[@]}" -i "$CONSOLE_SSH_KEY" -o IdentitiesOnly=yes "sandbox@$(cat "$STATE_DIR/$n.ip")" "$@"; }
console_create() {
  local id st j t0; t0=$(date +%s)
  id=$(capi POST /api/nodes "{\"name\":\"$1\",\"sshKeyId\":\"$CONSOLE_SSH_KEY_ID\",\"spec\":\"$CONSOLE_SPEC\"}" | jq -r '.id // empty')
  [ -n "$id" ] || { echo "console create failed"; return 1; }
  echo "$id" > "$STATE_DIR/$1.id"; echo "node=$id"
  local prev=""
  for i in $(seq 1 120); do
    j=$(capi GET "/api/nodes/$id"); st=$(jq -r .status <<<"$j")
    [ "$st" != "$prev" ] && echo "STATUS +$(( $(date +%s)-t0 ))s $st"; prev=$st
    case "$st" in running) jq -r .ipv4 <<<"$j" > "$STATE_DIR/$1.ip"; return 0;; failed|destroyed) return 1;; esac
    sleep 5
  done
  return 1
}
console_exec() { console_ssh "$1" "${*:2}"; }
console_destroy() {
  local id; id=$(cat "$STATE_DIR/$1.id" 2>/dev/null) || return 0
  capi DELETE "/api/nodes/$id" | jq -c '{id,status}'
  for i in $(seq 1 60); do [ "$(capi GET "/api/nodes/$id" | jq -r .status)" = destroyed ] && { echo "destroyed $id"; return 0; }; sleep 10; done
  echo "destroy not confirmed for $id"
}
console_list() { capi GET /api/nodes | jq '[.nodes[] | select((.name // "") | startswith("agro-mx-")) | select(.status != "destroyed" and .status != "failed")] | length'; }

px() { "${PROVIDER}_$1" "${@:2}"; }

wait_shell() {
  local i
  for i in $(seq 1 60); do px exec "$NAME" true >/dev/null 2>&1 && return 0; sleep 3; done
  return 1
}

upload() { local b64; b64=$(base64 -w0 "$2"); px exec "$NAME" "echo $b64 | base64 -d > $1"; }

run_detached() {
  upload /tmp/check.sh "$1" || return 1
  px exec "$NAME" "$2 setsid nohup bash /tmp/check.sh > /tmp/check.log 2>&1 < /dev/null & echo started"
}

poll_log() {
  local seen=0 misses=0 deadline=$(( $(date +%s) + ${1:-2400} )) out
  while [ "$(date +%s)" -lt "$deadline" ]; do
    sleep 15
    if out=$(px exec "$NAME" "tail -n +$((seen+1)) /tmp/check.log"); then
      misses=0
      if [ -n "$out" ]; then printf '%s\n' "$out"; seen=$(( seen + $(printf '%s\n' "$out" | wc -l) )); fi
      printf '%s\n' "$out" | grep -qE '^(SUMMARY|PROBE-END)' && return 0
    else
      misses=$((misses+1)); echo "poll miss $misses"; [ $misses -ge 6 ] && return 1
    fi
  done
  echo "poll deadline reached"; return 1
}

driver_rows() {
  echo "== driver rows"
  px exec "$NAME" "tmux new-session -d -s r09 'sleep 900' && echo started" >/dev/null 2>&1
  sleep 5
  px exec "$NAME" "tmux has-session -t r09" >/dev/null 2>&1 && echo "RESULT R09-disconnect PASS tmux session survives the client exit" || echo "RESULT R09-disconnect FAIL tmux session gone after the client exit"
  local code
  case "$PROVIDER" in
    exedev)
      echo "RESULT R10-ssh-inbound PASS ssh $NAME.exe.xyz"
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$(exedev_https_url "$NAME")")
      case "$code" in 200) echo "RESULT R11-https-port PASS https 200";; 30*|401|403) echo "RESULT R11-https-port SKIPPED proxy answers $code: private by default, needs share";; *) echo "RESULT R11-https-port FAIL http=$code";; esac ;;
    console)
      echo "RESULT R10-ssh-inbound PASS ssh sandbox@$(cat "$STATE_DIR/$NAME.ip")"
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "http://$(cat "$STATE_DIR/$NAME.ip"):8000/")
      echo "RESULT R11-https-port SKIPPED no HTTPS endpoint on the node; plain http :8000 answers $code" ;;
    vercel)
      echo "RESULT R10-ssh-inbound FAIL API exec only, no standard SSH endpoint"
      echo "RESULT R11-https-port SKIPPED no --publish-port at create" ;;
  esac
}

finish() {
  trap '' PIPE HUP INT TERM
  {
    [ "${KEEP:-0}" = 1 ] && { echo "== keep $NAME"; return; }
    echo "== destroy $NAME"; px destroy "$NAME"
    echo "remaining $MATRIX_TAG resources on $PROVIDER: $(px list)"
    echo "RUN DONE"
  } >>"$LOG" 2>&1
}
