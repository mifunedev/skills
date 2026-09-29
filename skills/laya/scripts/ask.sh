#!/usr/bin/env bash
set -euo pipefail

URL="${LAYA_URL:-http://127.0.0.1:8000/v1/systemone}"
MODEL="${LAYA_MODEL:-}"
KEY="${LAYA_API_KEY:-}"
TIMEOUT="${LAYA_TIMEOUT:-60}"
RETRIES=3

usage() {
  cat <<'USAGE'
ask.sh — send one System One request to a Laya server

  bash scripts/ask.sh <request.json>     request from a file
  bash scripts/ask.sh -                  request from stdin
  bash scripts/ask.sh --check            report server health from /health

  Request: {"state": ..., "questions": {...}}. The Laya router picks the
           checkpoint unless "model" or $LAYA_MODEL names english,
           multilingual, or typed-decisions.
  Env:     LAYA_URL, LAYA_MODEL, LAYA_API_KEY (only when the server sets one),
           LAYA_TIMEOUT.
  Output:  response JSON on stdout, plus "latency_ms=<n>" on stderr.
  Exit:    0 answered or check done, 1 request failed, 2 usage error.
USAGE
}

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "ask.sh: $1 is not on PATH" >&2; exit 2; }
}

auth=()
if [ -n "$KEY" ]; then auth=(-H "authorization: Bearer $KEY"); fi

post() {
  local body="$1" attempt=0 meta status seconds
  while :; do
    meta="$(curl -sS -o "$out" -w '%{http_code} %{time_total}' --max-time "$TIMEOUT" \
      ${auth[@]+"${auth[@]}"} -H 'content-type: application/json' \
      --data-binary "$body" "$URL")" || meta="000 0"
    status="${meta%% *}"
    seconds="${meta##* }"
    case "$status" in
      2??)
        awk -v s="$seconds" 'BEGIN { printf "latency_ms=%d\n", s * 1000 }' >&2
        jq -e '.answers | type == "object"' "$out" >/dev/null 2>&1 || {
          echo "Laya returned a body with no answers object." >&2; cat "$out" >&2; return 1; }
        cat "$out"
        return 0
        ;;
      503 | 000)
        if [ "$attempt" -lt "$RETRIES" ]; then
          attempt=$((attempt + 1))
          sleep "$((attempt * attempt))"
          continue
        fi
        ;;
    esac
    case "$status" in
      000) echo "Laya is unreachable at $URL. Is laya-serve running?" >&2 ;;
      401) echo "Laya rejected the request (HTTP 401). Set LAYA_API_KEY to the server key." >&2 ;;
      413) echo "Laya refused the request size (HTTP 413). A choice allows at most 100 options." >&2 ;;
      422) echo "Laya rejected the request body (HTTP 422). Check option budget and score levels." >&2 ;;
      503) echo "Laya is busy; retries exhausted (HTTP 503)." >&2 ;;
      *) echo "Laya failed (HTTP $status)." >&2 ;;
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
    health="${URL%/v1/systemone}/health"
    if curl -sS --max-time 10 ${auth[@]+"${auth[@]}"} "$health" -o "$out"; then
      echo "Laya is up at $health:"
      jq . "$out" 2>/dev/null || cat "$out"
    else
      echo "Laya is not reachable at $health." >&2
      echo "  Start it as SKILL.md \"Start the server\" describes, then run --check again." >&2
    fi
    exit 0
    ;;
esac

if [ "$1" = "-" ]; then raw="$(cat)"; else raw="$(cat -- "$1")"; fi
body="$(jq -ce --arg m "$MODEL" 'if $m != "" then {model: $m} + . else . end' <<<"$raw")" || {
  echo "ask.sh: request is not valid JSON" >&2; exit 2; }
jq -e '(.questions | type == "object") and (.questions | length > 0) and has("state")' \
  <<<"$body" >/dev/null || { echo "ask.sh: request needs state and a non-empty questions map" >&2; exit 2; }
post "$body"
