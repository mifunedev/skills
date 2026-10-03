#!/usr/bin/env bash
set -euo pipefail

BACKEND="${SYSTEM_ONE_BACKEND:-jev}"
if [ "${1:-}" = "--backend" ]; then BACKEND="${2:-}"; shift 2 || true; fi
RETRIES=3

case "$BACKEND" in
  jev)
    URL="${JEV_URL:-https://api.typesafe.ai/v1/systemone}"
    MODEL="${JEV_MODEL:-jev-latest}"
    KEY="${TYPESAFE_API_KEY:-}"
    TIMEOUT="${JEV_TIMEOUT:-30}"
    NAME=Jev
    ;;
  laya)
    URL="${LAYA_URL:-http://127.0.0.1:8000/v1/systemone}"
    MODEL="${LAYA_MODEL:-}"
    KEY="${LAYA_API_KEY:-}"
    TIMEOUT="${LAYA_TIMEOUT:-60}"
    NAME=Laya
    ;;
  *) echo "ask.sh: unknown backend '$BACKEND'; use jev or laya" >&2; exit 2 ;;
esac

usage() {
  cat <<'USAGE'
ask.sh — send one System One request to Jev (default) or a Laya server

  bash scripts/ask.sh [--backend jev|laya] <request.json>   request from a file
  bash scripts/ask.sh [--backend jev|laya] -                request from stdin
  bash scripts/ask.sh --check                  Jev: report whether TYPESAFE_API_KEY is set
  bash scripts/ask.sh --check --live           Jev: also send one minimal request
  bash scripts/ask.sh --backend laya --check   Laya: report server health from /health

  Backend: --backend, else $SYSTEM_ONE_BACKEND, else jev.
  Request: {"state": ..., "questions": {...}}. Jev sets "model" to $JEV_MODEL
           (jev-latest). Laya lets its router pick a checkpoint unless "model"
           or $LAYA_MODEL names english, multilingual, or typed-decisions.
  Env Jev:  TYPESAFE_API_KEY (required), JEV_URL, JEV_MODEL, JEV_TIMEOUT.
  Env Laya: LAYA_URL, LAYA_MODEL, LAYA_API_KEY (only when the server sets one),
            LAYA_TIMEOUT.
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

auth=()
if [ -n "$KEY" ]; then auth=(-H "authorization: Bearer $KEY"); fi

retryable() {
  case "$BACKEND:$1" in
    jev:429 | jev:529 | laya:503 | *:000) return 0 ;;
    *) return 1 ;;
  esac
}

explain() {
  case "$BACKEND:$1" in
    *:000) echo "$NAME is unreachable at $URL.$([ "$BACKEND" = laya ] && echo ' Is laya-serve running?')" ;;
    jev:401) echo "Jev rejected TYPESAFE_API_KEY (HTTP 401)." ;;
    jev:403) echo "Jev denied this key for model $MODEL (HTTP 403)." ;;
    jev:422) echo "Jev rejected the request body (HTTP 422). Fix the questions." ;;
    jev:429 | jev:529) echo "Jev is rate limiting or overloaded; retries exhausted (HTTP $1)." ;;
    laya:401) echo "Laya rejected the request (HTTP 401). Set LAYA_API_KEY to the server key." ;;
    laya:413) echo "Laya refused the request size (HTTP 413). A choice allows at most 100 options." ;;
    laya:422) echo "Laya rejected the request body (HTTP 422). Check option budget and score levels." ;;
    laya:503) echo "Laya is busy; retries exhausted (HTTP 503)." ;;
    *) echo "$NAME failed (HTTP $1)." ;;
  esac
}

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
          echo "$NAME returned a body with no answers object." >&2; cat "$out" >&2; return 1; }
        cat "$out"
        return 0
        ;;
    esac
    if retryable "$status" && [ "$attempt" -lt "$RETRIES" ]; then
      attempt=$((attempt + 1))
      sleep "$((attempt * attempt))"
      continue
    fi
    explain "$status" >&2
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
    if [ "$BACKEND" = laya ]; then
      health="${URL%/v1/systemone}/health"
      if curl -sS --max-time 10 ${auth[@]+"${auth[@]}"} "$health" -o "$out"; then
        echo "Laya is up at $health:"
        jq . "$out" 2>/dev/null || cat "$out"
      else
        echo "Laya is not reachable at $health." >&2
        echo "  Start it as references/laya.md \"Start the server\" describes, then run --check again." >&2
      fi
      exit 0
    fi
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

if [ "$BACKEND" = jev ] && [ -z "$KEY" ]; then no_key; exit 1; fi
if [ "$1" = "-" ]; then raw="$(cat)"; else raw="$(cat -- "$1")"; fi
body="$(jq -ce --arg m "$MODEL" 'if $m != "" then {model: $m} + . else . end' <<<"$raw")" || {
  echo "ask.sh: request is not valid JSON" >&2; exit 2; }
jq -e '(.questions | type == "object") and (.questions | length > 0) and has("state")' \
  <<<"$body" >/dev/null || { echo "ask.sh: request needs state and a non-empty questions map" >&2; exit 2; }
post "$body"
