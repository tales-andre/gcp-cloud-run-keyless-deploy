# Static rules for the Terraform code (conftest, hcl2 parser). They read the
# code as written, with no plan and no cloud account, so they also catch
# things `terraform test` cannot: a test only sees resources that exist in
# the module, so "no service account key anywhere" is checked here.
#
#   conftest test --parser hcl2 --policy policy <files>

package main

import rego.v1

# GitHub logs in with Workload Identity Federation. A downloaded key would be
# a long-lived credential that can leak.
deny contains msg if {
	some name
	input.resource.google_service_account_key[name]
	msg := sprintf("google_service_account_key.%s: service account keys are not allowed; CI logs in with Workload Identity Federation", [name])
}

# A secret version in Terraform puts the secret value in the state file.
deny contains msg if {
	some name
	input.resource.google_secret_manager_secret_version[name]
	msg := sprintf("google_secret_manager_secret_version.%s: add secret values with gcloud, never through Terraform state", [name])
}

# Opening a service to the internet goes through `public = true` in the
# cloud-run-service module, never through a member written into an IAM grant.
public_principals := {"allUsers", "allAuthenticatedUsers"}

deny contains msg if {
	some type, name
	block := input.resource[type][name][_]
	endswith(type, "_iam_member")
	block.member in public_principals
	msg := sprintf("%s.%s: %s written into an IAM grant; use public = true on the service instead", [type, name, block.member])
}

deny contains msg if {
	some type, name
	block := input.resource[type][name][_]
	endswith(type, "_iam_binding")
	some member in block.members
	member in public_principals
	msg := sprintf("%s.%s: %s written into an IAM grant; use public = true on the service instead", [type, name, member])
}

# Switching off the IAM check would make even staging public.
deny contains msg if {
	some name
	block := input.resource.google_cloud_run_v2_service[name][_]
	block.invoker_iam_disabled == true
	msg := sprintf("google_cloud_run_v2_service.%s: invoker_iam_disabled = true lets anyone call the service", [name])
}

# Basic roles and key-minting roles are never needed here.
forbidden_roles := {
	"roles/owner",
	"roles/editor",
	"roles/iam.serviceAccountKeyAdmin",
	"roles/iam.serviceAccountTokenCreator",
}

deny contains msg if {
	some type, name
	block := input.resource[type][name][_]
	startswith(type, "google_")
	contains(type, "_iam_")
	block.role in forbidden_roles
	msg := sprintf("%s.%s: %s is broader than anything this setup needs", [type, name, block.role])
}

# A Workload Identity provider without a condition would accept a token from
# any GitHub repository.
deny contains msg if {
	some name
	block := input.resource.google_iam_workload_identity_pool_provider[name][_]
	not block.attribute_condition
	msg := sprintf("google_iam_workload_identity_pool_provider.%s: attribute_condition is required", [name])
}

# A literal condition must check the repository. A computed one (as in
# modules/github-wif) is checked on its planned value by terraform test.
deny contains msg if {
	some name
	block := input.resource.google_iam_workload_identity_pool_provider[name][_]
	is_string(block.attribute_condition)
	not startswith(block.attribute_condition, "${")
	not contains(block.attribute_condition, "assertion.repository")
	msg := sprintf("google_iam_workload_identity_pool_provider.%s: attribute_condition must check assertion.repository", [name])
}
