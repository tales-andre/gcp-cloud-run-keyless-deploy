#!/usr/bin/env bash
# Offline Terraform checks: format, validate, and `terraform test` with a
# mocked Google provider. No cloud account and no credentials are used.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Fail closed: whatever is set in this shell, Terraform gets no Google
# credentials. The tests use mock_provider, so they never need any.
unset GOOGLE_CREDENTIALS GOOGLE_CLOUD_KEYFILE_JSON GCLOUD_KEYFILE_JSON \
  GOOGLE_OAUTH_ACCESS_TOKEN GOOGLE_IMPERSONATE_SERVICE_ACCOUNT \
  CLOUDSDK_AUTH_ACCESS_TOKEN_FILE CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE
export GOOGLE_APPLICATION_CREDENTIALS=/nonexistent/no-credentials.json
CLOUDSDK_CONFIG="$(mktemp -d)"
export CLOUDSDK_CONFIG
export TF_IN_AUTOMATION=1
export TF_INPUT=0

step() { printf '\n==> %s\n' "$*"; }

step "terraform fmt"
terraform fmt -check -recursive -diff infra
terraform fmt -check -recursive -diff import

step "terraform validate (infra/)"
terraform -chdir=infra init -backend=false -no-color >/dev/null
terraform -chdir=infra validate -no-color

# import/ needs a real project to import from, so it is only validated.
step "terraform validate (import/, never executed)"
terraform -chdir=import init -backend=false -no-color >/dev/null
terraform -chdir=import validate -no-color

step "terraform test (modules and root, mock provider)"
terraform -chdir=infra test -no-color

step "terraform test with envs/staging.tfvars"
terraform -chdir=infra test -no-color -test-directory=tests/staging -var-file=envs/staging.tfvars

step "terraform test with envs/production.tfvars"
terraform -chdir=infra test -no-color -test-directory=tests/production -var-file=envs/production.tfvars

printf '\nAll Terraform checks passed, offline.\n'
