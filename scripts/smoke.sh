#!/usr/bin/env bash
# Smoke test for the PDF chatbot: one question the sample documents answer
# (it must cite the file and page) and one they do not (it must refuse).
#
#   scripts/smoke.sh
#       Builds app-src/ with its own Dockerfile and runs it locally in
#       Docker, offline (no AI provider, no key), read-only, as non-root.
#   SMOKE_URL=https://<service>.run.app ID_TOKEN=<token> scripts/smoke.sh
#       Asks an already running service instead (used after a deploy).
#
# Needs docker (local mode), curl and jq.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# Git Bash on Windows would rewrite /tmp below into a Windows path.
export MSYS_NO_PATHCONV=1

IMAGE="${IMAGE:-pdf-chatbot:smoke}"
PORT="${PORT:-8000}"
CONTAINER="pdf-chatbot-smoke"
REFUSAL="I couldn't find this in the documents."
started_container=""

cleanup() {
  if [ -n "$started_container" ]; then
    if [ "${KEEP_LOGS:-}" = "1" ] || [ "${smoke_failed:-1}" = "1" ]; then
      echo "--- container logs ---"
      docker logs "$CONTAINER" 2>&1 | tail -n 40 || true
    fi
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

if [ -z "${SMOKE_URL:-}" ]; then
  if [ -z "${SKIP_BUILD:-}" ]; then
    [ -f app-src/Dockerfile ] || fail "app-src/ is missing; run scripts/fetch-app.sh first"
    docker build -q -t "$IMAGE" app-src >/dev/null
    echo "built $IMAGE from app-src/ ($(git -C app-src rev-parse --short HEAD 2>/dev/null || echo unknown))"
  fi
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  # Close to how Cloud Run runs it: PORT is set, nothing is written to the
  # image, no Linux capabilities, no AI provider.
  docker run -d --name "$CONTAINER" -p "127.0.0.1:${PORT}:8000" \
    --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
    -e PORT=8000 -e LLM_PROVIDER=none "$IMAGE" >/dev/null
  started_container=1
  SMOKE_URL="http://127.0.0.1:${PORT}"
fi
SMOKE_URL="${SMOKE_URL%/}"

auth=()
if [ -n "${ID_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer ${ID_TOKEN}")
fi

echo "waiting for ${SMOKE_URL}/health"
health=""
for _ in $(seq 1 60); do
  if health="$(curl -fsS "${auth[@]}" "${SMOKE_URL}/health" 2>/dev/null)"; then
    break
  fi
  health=""
  sleep 1
done
[ -n "$health" ] || fail "/health did not answer within 60 seconds"
echo "health: $health"
[ "$(jq -r '.status' <<<"$health" | tr -d '\r')" = "ok" ] || fail "/health is not ok"
if [ -n "$started_container" ]; then
  jq -e '.mode | startswith("extractive")' <<<"$health" >/dev/null || fail "expected the offline (extractive) mode"
fi

ask() {
  local question="$1"
  curl -fsS "${auth[@]}" -X POST "${SMOKE_URL}/chat" \
    -H "Content-Type: application/json" \
    -d "$(jq -cn --arg q "$question" '{question: $q}')"
}

q1="How much does white-glove delivery cost?"
echo
echo "Q: $q1"
r1="$(ask "$q1")"
jq -r '"A: \(.answer)\n   cited: \([.citations[] | "\(.source) page \(.page)"] | join(", "))"' <<<"$r1" | tr -d '\r'
[ "$(jq -r '.refused' <<<"$r1" | tr -d '\r')" = "false" ] || fail "an answerable question was refused"
jq -e '.answer | contains("$149")' <<<"$r1" >/dev/null || fail "the answer does not contain the price from the document"
jq -e '[.citations[] | select(.source == "acme-shipping-faq.pdf" and .page == 2)] | length >= 1' <<<"$r1" >/dev/null \
  || fail "the answer does not cite acme-shipping-faq.pdf page 2"

q2="Can I pay with cryptocurrency?"
echo
echo "Q: $q2"
r2="$(ask "$q2")"
jq -r '"A: \(.answer)"' <<<"$r2" | tr -d '\r'
[ "$(jq -r '.refused' <<<"$r2" | tr -d '\r')" = "true" ] || fail "an out-of-scope question was answered"
[ "$(jq -r '.answer' <<<"$r2" | tr -d '\r')" = "$REFUSAL" ] || fail "the refusal text changed"
jq -e '.citations | length == 0' <<<"$r2" >/dev/null || fail "a refusal must not cite anything"

smoke_failed=0
echo
echo "OK: answered with a page citation, refused what the documents do not say"
