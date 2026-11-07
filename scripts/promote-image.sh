#!/usr/bin/env bash
# Copy an already built image into an environment's Artifact Registry
# without rebuilding it, and prove the digest did not change.
#
# Environment:
#   SOURCE_IMAGE      image without tag or digest, e.g. ghcr.io/owner/repo/pdf-chatbot
#   DIGEST            sha256:... of the image that passed the smoke test
#   TARGET_REPOSITORY Artifact Registry repository, e.g. us-central1-docker.pkg.dev/<project>/pdf-chatbot
#   SOURCE_USER, SOURCE_TOKEN   optional login for the source registry (GHCR: actor + GITHUB_TOKEN)
#   TARGET_TOKEN      optional OAuth access token for Artifact Registry (from google-github-actions/auth)
#   CRANE_FLAGS       optional extra flags, e.g. --insecure for a local test registry
#
# Prints image=<target>@<digest> to $GITHUB_OUTPUT when it is set.
set -euo pipefail

: "${SOURCE_IMAGE:?}" "${DIGEST:?}" "${TARGET_REPOSITORY:?}"
[[ "$DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "DIGEST must be sha256:<64 hex>" >&2; exit 1; }

read -r -a flags <<<"${CRANE_FLAGS:-}"

if [ -n "${SOURCE_TOKEN:-}" ]; then
  printf '%s' "$SOURCE_TOKEN" | crane auth login "${SOURCE_IMAGE%%/*}" -u "${SOURCE_USER:?}" --password-stdin
fi
if [ -n "${TARGET_TOKEN:-}" ]; then
  printf '%s' "$TARGET_TOKEN" | crane auth login "${TARGET_REPOSITORY%%/*}" -u oauth2accesstoken --password-stdin
fi

# The tag is derived from the digest, so promoting the same image again
# (a rollback) writes the same tag to the same image: allowed even with
# immutable tags.
tag="d-${DIGEST:7:12}"
target="${TARGET_REPOSITORY}/pdf-chatbot"

crane copy "${flags[@]}" "${SOURCE_IMAGE}@${DIGEST}" "${target}:${tag}"
copied="$(crane digest "${flags[@]}" "${target}:${tag}")"
if [ "$copied" != "$DIGEST" ]; then
  echo "digest changed in the copy: $DIGEST -> $copied" >&2
  exit 1
fi

echo "promoted ${target}@${DIGEST}"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "image=${target}@${DIGEST}" >>"$GITHUB_OUTPUT"
fi
