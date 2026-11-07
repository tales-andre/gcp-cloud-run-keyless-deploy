# Runs against the real envs/staging.tfvars:
#   terraform test -test-directory=tests/staging -var-file=envs/staging.tfvars
# The file sets no variables of its own, so the values come from the tfvars.

mock_provider "google" {
  source          = "./tests/mocks"
  override_during = plan
}

run "staging_tfvars_are_safe" {
  command = plan

  assert {
    condition     = var.environment == "staging"
    error_message = "Run this file with -var-file=envs/staging.tfvars."
  }

  assert {
    condition     = var.public == false
    error_message = "Staging must not be public."
  }

  assert {
    condition     = length(setintersection(toset(output.invokers), toset(["allUsers", "allAuthenticatedUsers"]))) == 0
    error_message = "Staging must not be callable by allUsers or allAuthenticatedUsers."
  }

  assert {
    condition     = output.max_instance_count >= 1 && output.max_instance_count <= 3
    error_message = "Staging is for testers: keep its cap small."
  }

  assert {
    condition     = endswith(output.attribute_condition, "assertion.ref == 'refs/heads/main' && assertion.environment == 'staging'")
    error_message = "Staging deploys come from main, in the staging GitHub environment."
  }

  assert {
    condition     = var.llm_provider == "none" && output.llm_api_key_secret == null
    error_message = "Staging runs offline, with no AI key."
  }
}
