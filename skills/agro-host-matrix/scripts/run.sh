#!/usr/bin/env bash
set -uo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"
usage() { echo "usage: run.sh <vercel|exedev|console> <rows.sh|cg-probe.sh|--preflight>" >&2; exit 2; }
PROVIDER=${1:-}; CHECK=${2:-}
case "$PROVIDER" in vercel|exedev|console) ;; *) usage;; esac
[ -n "$CHECK" ] || usage
if [ "$CHECK" = --preflight ]; then px preflight && { echo "preflight ok: $PROVIDER"; exit 0; }; echo "preflight failed: $PROVIDER" >&2; exit 1; fi
[ -f "$DIR/$CHECK" ] && CHECK="$DIR/$CHECK"
[ -f "$CHECK" ] || usage
NAME=agro-mx-$(date +%m%d-%H%M%S)
LOG="$MATRIX_OUT/$PROVIDER-$(basename "$CHECK" .sh)-$(date +%Y%m%d-%H%M%S).log"
echo "log: $LOG"
exec >>"$LOG" 2>&1
trap finish EXIT
trap "" HUP
trap "exit 130" INT TERM
echo "== $PROVIDER $NAME check=$(basename "$CHECK") image=${IMAGE:-default} date=$(date -u +%FT%TZ)"
t0=$(now); px create "$NAME"; t1=$(now)
wait_shell || { echo "RESULT R13-time-to-shell FAIL no shell"; exit 1; }
t2=$(now)
echo "TIMING create_return_s=$(elapsed "$t0" "$t1") first_shell_s=$(elapsed "$t0" "$t2")"
fwd="T_CREATE_REQ=$t0 T_FIRST_SHELL=$t2"
for v in GET_AGRO_URL AGRO_JS_URL SANDBOX_IMAGE; do [ -n "${!v:-}" ] && fwd+=" $v=${!v}"; done
echo "build under test: get_agro=${GET_AGRO_URL:-release} agro_js=${AGRO_JS_URL:-release} sandbox_image=${SANDBOX_IMAGE:-cli default} vm_image=${IMAGE:-provider default}"
run_detached "$CHECK" "$fwd" || exit 1
poll_log 2400 && driver_rows
