#!/usr/bin/env bash
set -euo pipefail

URL="${JEV_URL:-https://api.typesafe.ai/v1/systemone}"
MODEL="${JEV_MODEL:-jev-latest}"
KEY="${TYPESAFE_API_KEY:-}"
TIMEOUT="${JEV_TIMEOUT:-30}"
RETRIES=3

usage() {
  cat <<'USAGE'
ask.sh — send one System One request to TypeSafe Jev

  bash scripts/ask.sh <request.json>     request from a file
  bash scripts/ask.sh -                  request from stdin
  bash scripts/ask.sh --check            report whether TYPESAFE_API_KEY is set
  bash scripts/ask.sh --check --live     also send one minimal request

  Request: {"state": ..., "questions": {...}}; "model" defaults to $JEV_MODEL.
  Env:     TYPESAFE_API_KEY (required), JEV_URL, JEV_MODEL, JEV_TIMEOUT.
  Output:  response JSON on stdout, plus "latency_ms=<n>" on stderr.
  Exit:    0 answered or check done, 1 request failed, 2 usage error.
USAGE
}

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "ask.sh: $1 is not on PATH" >&2; exit 2; }
}

no_key() {
  echo "Jev is not configured: TYPESAFE_API_KEY is unset." >&2
  echo "  Get a key at https://typesafe.ai, then: export TYPESAFE_API_KEY=<key>" >&2
}

post() {
  local body="$1" attempt=0 meta status seconds
  while :; do
    meta="$(curl -sS -o "$out" -w '%{http_code} %{time_total}' --max-time "$TIMEOUT" \
      -H "authorization: Bearer $KEY" -H 'content-type: application/json' \
      --data-binary "$body" "$URL")" || meta="000 0"
    status="${meta%% *}"
    seconds="${meta##* }"
    case "$status" in
      2??)
        awk -v s="$seconds" 'BEGIN { printf "latency_ms=%d\n", s * 1000 }' >&2
        jq -e '.answers | type == "object"' "$out" >/dev/null 2>&1 || {
          echo "Jev returned a body with no answers object." >&2; cat "$out" >&2; return 1; }
        cat "$out"
        return 0
        ;;
      429 | 529 | 000)
        if [ "$attempt" -lt "$RETRIES" ]; then
          attempt=$((attempt + 1))
          sleep "$((attempt * attempt))"
          continue
        fi
        ;;
    esac
    case "$status" in
      000) echo "Jev is unreachable at $URL." >&2 ;;
      401) echo "Jev rejected TYPESAFE_API_KEY (HTTP 401)." >&2 ;;
      403) echo "Jev denied this key for model $MODEL (HTTP 403)." >&2 ;;
      422) echo "Jev rejected the request body (HTTP 422). Fix the questions." >&2 ;;
      429 | 529) echo "Jev is rate limiting or overloaded; retries exhausted (HTTP $status)." >&2 ;;
      *) echo "Jev failed (HTTP $status)." >&2 ;;
    esac
    [ -s "$out" ] && cat "$out" >&2 && echo >&2
    return 1
  done
}

need curl
need jq
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
  --check)
    [ -n "$KEY" ] || { no_key; exit 0; }
    echo "TYPESAFE_API_KEY is set."
    if [ "${2:-}" = "--live" ]; then
      body='{"state":"ping","questions":{"ok":{"type":"noul","instructions":"Is this a greeting or a test message?"}}}'
      body="$(jq -c --arg m "$MODEL" '. + {model: $m}' <<<"$body")"
      if post "$body" >/dev/null; then echo "Jev answered at $URL."; else exit 1; fi
    fi
    exit 0
    ;;
esac

[ -n "$KEY" ] || { no_key; exit 1; }
if [ "$1" = "-" ]; then raw="$(cat)"; else raw="$(cat -- "$1")"; fi
body="$(jq -ce --arg m "$MODEL" '{model: $m} + .' <<<"$raw")" || {
  echo "ask.sh: request is not valid JSON" >&2; exit 2; }
jq -e '(.questions | type == "object") and (.questions | length > 0) and has("state")' \
  <<<"$body" >/dev/null || { echo "ask.sh: request needs state and a non-empty questions map" >&2; exit 2; }
post "$body"
