#!/usr/bin/env bash
# Everything CI runs, in one go, on your machine. No cloud account needed.
# Requires terraform, docker, git, curl and jq.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

scripts/test-infra.sh
scripts/lint.sh
scripts/fetch-app.sh
scripts/smoke.sh

printf '\nEverything passed.\n'
