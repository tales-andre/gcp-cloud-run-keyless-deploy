#!/usr/bin/env bash
# Static checks on the code at rest. Nothing here needs a cloud account.
#
#   scripts/lint.sh                 # everything
#   scripts/lint.sh tflint checkov  # some of it
#
# Each tool runs from the pinned image in scripts/tools.env (Docker needed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/tools.env
source scripts/tools.env

# Docker on Windows (Git Bash) needs a Windows path and no path rewriting.
HOST_ROOT="$(pwd -W 2>/dev/null || pwd)"
export MSYS_NO_PATHCONV=1

step() { printf '\n==> %s\n' "$*"; }

tflint() {
  step "tflint (terraform + google rulesets)"
  # One container: --init downloads the google ruleset, then lint every module.
  docker run --rm -v "$HOST_ROOT:/work" -w /work/infra \
    -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
    --entrypoint /bin/sh "$TFLINT_IMAGE" -c \
    'tflint --init >/dev/null && tflint --recursive --config /work/infra/.tflint.hcl --format compact'
}

checkov() {
  step "checkov (infra/)"
  docker run --rm -v "$HOST_ROOT:/work" -w /work "$CHECKOV_IMAGE" \
    --directory infra --framework terraform --config-file .checkov.yaml --compact --quiet
}

conftest() {
  step "conftest verify (policy unit tests)"
  docker run --rm -v "$HOST_ROOT:/work" -w /work "$CONFTEST_IMAGE" verify --policy policy

  step "conftest test (the real code must pass)"
  # shellcheck disable=SC2046
  docker run --rm -v "$HOST_ROOT:/work" -w /work "$CONFTEST_IMAGE" \
    test --parser hcl2 --policy policy $(git ls-files --cached --others --exclude-standard \
      'infra/*.tf' 'infra/**/*.tf' 'infra/envs/*.tfvars' 'import/*.tf')

  step "conftest test (the unsafe examples must fail)"
  local out status=0
  out="$(docker run --rm -v "$HOST_ROOT:/work" -w /work "$CONFTEST_IMAGE" \
    test --parser hcl2 --policy policy --no-color policy/testdata/unsafe 2>&1)" || status=$?
  printf '%s\n' "$out"
  if [ "$status" -eq 0 ]; then
    echo "FAIL: the unsafe examples passed the policy check" >&2
    exit 1
  fi
  for f in service-account-key.tf public-invoker.tf secret-in-state.tf staging-public.tfvars; do
    if ! grep -q "FAIL - policy/testdata/unsafe/$f" <<<"$out"; then
      echo "FAIL: policy/testdata/unsafe/$f was not rejected" >&2
      exit 1
    fi
  done
  echo "OK: every unsafe example was rejected"
}

actionlint() {
  step "actionlint (.github/workflows)"
  docker run --rm -v "$HOST_ROOT:/work" -w /work "$ACTIONLINT_IMAGE" -no-color
}

zizmor() {
  step "zizmor (workflow security)"
  docker run --rm -v "$HOST_ROOT:/work" -w /work "$ZIZMOR_IMAGE" \
    --offline --no-progress --persona=auditor .github/workflows
}

shellcheck() {
  step "shellcheck (scripts/)"
  docker run --rm -v "$HOST_ROOT:/work" -w /work "$SHELLCHECK_IMAGE" -x scripts/*.sh
}

steps=("$@")
[ ${#steps[@]} -eq 0 ] && steps=(tflint checkov conftest actionlint zizmor shellcheck)
for s in "${steps[@]}"; do
  case "$s" in
    tflint|checkov|conftest|actionlint|zizmor|shellcheck) "$s" ;;
    *) echo "unknown step: $s" >&2; exit 2 ;;
  esac
done
printf '\nAll lint steps passed: %s\n' "${steps[*]}"
