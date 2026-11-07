# GitHub Actions logs in with Workload Identity Federation instead of a
# stored key. These runs check the login condition on the planned values.
# The provider is a mock: nothing here calls Google Cloud.

mock_provider "google" {
  source          = "./tests/mocks"
  override_during = plan
}

variables {
  project_id          = "acme-chatbot-staging"
  pool_id             = "github-staging"
  github_repository   = "tales-andre/gcp-cloud-run-keyless-deploy"
  branch              = "main"
  github_environment  = "staging"
  deployer_account_id = "pdf-chatbot-ci-stg"
}

run "login_is_limited_to_this_repository_main_and_the_environment" {
  command = plan

  module {
    source = "./modules/github-wif"
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.sub == 'repo:tales-andre/gcp-cloud-run-keyless-deploy:environment:staging' && assertion.repository == 'tales-andre/gcp-cloud-run-keyless-deploy' && assertion.ref == 'refs/heads/main' && assertion.environment == 'staging'"
    error_message = "The login condition must pin the repository, the main branch and the GitHub environment."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.oidc[0].issuer_uri == "https://token.actions.githubusercontent.com"
    error_message = "Only GitHub's OIDC issuer may be trusted."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_mapping["attribute.repository"] == "assertion.repository"
    error_message = "attribute.repository must come from the token's repository claim: the impersonation grant matches on it."
  }

  assert {
    condition     = google_service_account_iam_member.github_impersonates_deployer.member == "principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-mock/attribute.repository/tales-andre/gcp-cloud-run-keyless-deploy"
    error_message = "Only identities from this repository may impersonate the deployer."
  }

  assert {
    condition     = google_service_account_iam_member.github_impersonates_deployer.role == "roles/iam.workloadIdentityUser"
    error_message = "The pool gets workloadIdentityUser on the deployer, nothing broader."
  }
}

run "repository_id_is_checked_once_known" {
  command = plan

  module {
    source = "./modules/github-wif"
  }

  variables {
    github_repository_id = "987654321"
  }

  assert {
    condition     = strcontains(google_iam_workload_identity_pool_provider.github.attribute_condition, "&& assertion.repository_id == '987654321' &&")
    error_message = "With the numeric repository ID set, a re-created repository with the same name cannot log in."
  }
}

run "without_an_environment_the_subject_pins_the_branch" {
  command = plan

  module {
    source = "./modules/github-wif"
  }

  variables {
    github_environment = ""
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.sub == 'repo:tales-andre/gcp-cloud-run-keyless-deploy:ref:refs/heads/main' && assertion.repository == 'tales-andre/gcp-cloud-run-keyless-deploy' && assertion.ref == 'refs/heads/main'"
    error_message = "Without an environment the subject claim must still pin the repository and the branch."
  }

  assert {
    condition     = !contains(keys(google_iam_workload_identity_pool_provider.github.attribute_mapping), "attribute.environment")
    error_message = "The environment claim is only mapped when a job must run in an environment."
  }
}

run "a_repository_name_cannot_inject_into_the_condition" {
  command = plan

  module {
    source = "./modules/github-wif"
  }

  variables {
    github_repository = "someone/repo' || true || '"
  }

  expect_failures = [var.github_repository]
}

run "a_branch_name_cannot_inject_into_the_condition" {
  command = plan

  module {
    source = "./modules/github-wif"
  }

  variables {
    branch = "main' || assertion.ref != '"
  }

  expect_failures = [var.branch]
}

# The same rules, as wired by the root module for each environment.

run "staging_wiring" {
  command = plan

  variables {
    environment        = "staging"
    max_instance_count = 2
  }

  assert {
    condition     = output.attribute_condition == "assertion.sub == 'repo:tales-andre/gcp-cloud-run-keyless-deploy:environment:staging' && assertion.repository == 'tales-andre/gcp-cloud-run-keyless-deploy' && assertion.ref == 'refs/heads/main' && assertion.environment == 'staging'"
    error_message = "Staging logins must come from this repository, main, and the staging GitHub environment."
  }
}

run "production_wiring" {
  command = plan

  variables {
    project_id         = "acme-chatbot-production"
    environment        = "production"
    max_instance_count = 5
    public             = true
  }

  assert {
    condition     = output.attribute_condition == "assertion.sub == 'repo:tales-andre/gcp-cloud-run-keyless-deploy:environment:production' && assertion.repository == 'tales-andre/gcp-cloud-run-keyless-deploy' && assertion.ref == 'refs/heads/main' && assertion.environment == 'production'"
    error_message = "Production logins must come from a job in the production GitHub environment, which requires approval."
  }
}

run "root_rejects_an_injected_repository_name" {
  command = plan

  variables {
    environment        = "staging"
    max_instance_count = 2
    github_repository  = "someone/repo' || true || '"
  }

  expect_failures = [var.github_repository]
}
