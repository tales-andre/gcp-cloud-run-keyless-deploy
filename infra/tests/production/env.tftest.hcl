# Runs against the real envs/production.tfvars:
#   terraform test -test-directory=tests/production -var-file=envs/production.tfvars
# The file sets no variables of its own, so the values come from the tfvars.

mock_provider "google" {
  source          = "./tests/mocks"
  override_during = plan
}

run "production_tfvars_are_safe" {
  command = plan

  assert {
    condition     = var.environment == "production"
    error_message = "Run this file with -var-file=envs/production.tfvars."
  }

  assert {
    condition     = output.max_instance_count >= 1 && output.max_instance_count <= 10
    error_message = "Production keeps a cap on instances."
  }

  assert {
    condition     = var.deletion_protection == true
    error_message = "Production is protected from terraform destroy."
  }

  assert {
    condition     = var.public ? output.invokers == tolist(["allUsers"]) : !contains(output.invokers, "allUsers")
    error_message = "Production is public only through public = true, and then allUsers is the only invoker (no deployer)."
  }

  assert {
    condition     = endswith(output.attribute_condition, "assertion.ref == 'refs/heads/main' && assertion.environment == 'production'")
    error_message = "Production deploys come from main, in the production GitHub environment (which needs approval)."
  }

  assert {
    condition     = var.project_id != "acme-chatbot-staging"
    error_message = "Production has its own project."
  }
}
