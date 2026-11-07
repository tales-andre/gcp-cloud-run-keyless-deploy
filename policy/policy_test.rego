# Unit tests for the policies: `conftest verify --policy policy`.

package main

import rego.v1

test_service_account_key_is_denied if {
	count(deny) > 0 with input as {"resource": {"google_service_account_key": {"ci": [{"service_account_id": "x"}]}}}
}

test_secret_version_is_denied if {
	count(deny) > 0 with input as {"resource": {"google_secret_manager_secret_version": {"key": [{"secret_data": "x"}]}}}
}

test_allusers_member_is_denied if {
	count(deny) > 0 with input as {"resource": {"google_cloud_run_v2_service_iam_member": {"open": [{"member": "allUsers", "role": "roles/run.invoker"}]}}}
}

test_allauthenticated_binding_is_denied if {
	count(deny) > 0 with input as {"resource": {"google_cloud_run_v2_service_iam_binding": {"open": [{"members": ["group:a@example.com", "allAuthenticatedUsers"], "role": "roles/run.invoker"}]}}}
}

test_invoker_iam_disabled_is_denied if {
	count(deny) > 0 with input as {"resource": {"google_cloud_run_v2_service": {"svc": [{"invoker_iam_disabled": true}]}}}
}

test_owner_role_is_denied if {
	count(deny) > 0 with input as {"resource": {"google_project_iam_member": {"ci": [{"role": "roles/owner", "member": "serviceAccount:ci@p.iam.gserviceaccount.com"}]}}}
}

test_token_creator_is_denied if {
	count(deny) > 0 with input as {"resource": {"google_service_account_iam_member": {"ci": [{"role": "roles/iam.serviceAccountTokenCreator", "member": "user:a@example.com"}]}}}
}

test_provider_without_condition_is_denied if {
	count(deny) > 0 with input as {"resource": {"google_iam_workload_identity_pool_provider": {"gh": [{"oidc": [{"issuer_uri": "https://token.actions.githubusercontent.com"}]}]}}}
}

test_provider_condition_must_check_repository if {
	count(deny) > 0 with input as {"resource": {"google_iam_workload_identity_pool_provider": {"gh": [{"attribute_condition": "assertion.ref == 'refs/heads/main'"}]}}}
}

test_narrow_grants_pass if {
	count(deny) == 0 with input as {"resource": {
		"google_cloud_run_v2_service_iam_member": {"deploy": [{"member": "${module.github.deployer_member}", "role": "roles/run.developer"}]},
		"google_iam_workload_identity_pool_provider": {"gh": [{"attribute_condition": "${local.attribute_condition}"}]},
	}}
}

test_public_staging_is_denied if {
	count(deny) > 0 with input as {"environment": "staging", "public": true, "max_instance_count": 2}
}

test_allusers_in_staging_members_is_denied if {
	count(deny) > 0 with input as {"environment": "staging", "invoker_members": ["allUsers"], "max_instance_count": 2}
}

test_public_production_passes if {
	count(deny) == 0 with input as {"environment": "production", "public": true, "max_instance_count": 5}
}

test_missing_cap_is_denied if {
	count(deny) > 0 with input as {"environment": "production", "public": true}
}

test_huge_cap_is_denied if {
	count(deny) > 0 with input as {"environment": "production", "max_instance_count": 500}
}

test_private_staging_passes if {
	count(deny) == 0 with input as {"environment": "staging", "public": false, "invoker_members": ["group:testers@example.com"], "max_instance_count": 2}
}
