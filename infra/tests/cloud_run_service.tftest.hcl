# The Cloud Run module on its own: instance cap, runtime identity, who may
# call it, and how secrets reach the container. Mock provider only.

mock_provider "google" {
  source          = "./tests/mocks"
  override_during = plan
}

override_resource {
  target          = google_service_account.runtime
  override_during = plan
  values = {
    email  = "pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"
    member = "serviceAccount:pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"
    name   = "projects/acme-chatbot-staging/serviceAccounts/pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"
  }
}

variables {
  project_id         = "acme-chatbot-staging"
  region             = "us-central1"
  name               = "pdf-chatbot-staging"
  image              = "us-docker.pkg.dev/cloudrun/container/hello"
  max_instance_count = 2
  invoker_members    = ["group:chatbot-testers@example.com"]
  env                = { LLM_PROVIDER = "none" }
}

run "private_service_with_a_cap_and_its_own_identity" {
  command = plan

  module {
    source = "./modules/cloud-run-service"
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].scaling[0].max_instance_count == 2
    error_message = "The instance cap must be set from max_instance_count."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].scaling[0].min_instance_count == 0
    error_message = "The service must scale to zero by default."
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_binding.invokers[0].members == toset(["group:chatbot-testers@example.com"])
    error_message = "Only the listed members may call a private service."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.invoker_iam_disabled == false
    error_message = "The IAM check on requests must never be switched off."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].service_account == "pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"
    error_message = "The container must run as its own runtime service account, not the default compute account."
  }

  assert {
    condition     = google_service_account.runtime.account_id == "pdf-chatbot-staging-run"
    error_message = "The runtime service account is named after the service."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].containers[0].ports[0].container_port == 8000
    error_message = "The chatbot image listens on 8000."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].containers[0].startup_probe[0].http_get[0].path == "/health"
    error_message = "The startup probe must use the chatbot's /health endpoint."
  }

  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].vpc_access) == 0
    error_message = "Without a database the service needs no VPC egress."
  }
}

run "public_means_allusers_and_nothing_hidden" {
  command = plan

  module {
    source = "./modules/cloud-run-service"
  }

  variables {
    public          = true
    invoker_members = []
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_binding.invokers[0].members == toset(["allUsers"])
    error_message = "public = true grants the invoker role to allUsers, visibly, in one place."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.invoker_iam_disabled == false
    error_message = "Even a public service keeps the IAM check on."
  }
}

run "nobody_can_call_it_without_a_grant" {
  command = plan

  module {
    source = "./modules/cloud-run-service"
  }

  variables {
    invoker_members = []
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_binding.invokers) == 0
    error_message = "Without public = true and without members, nobody gets the invoker role."
  }
}

run "allusers_cannot_sneak_in_through_the_member_list" {
  command = plan

  module {
    source = "./modules/cloud-run-service"
  }

  variables {
    invoker_members = ["group:chatbot-testers@example.com", "allAuthenticatedUsers"]
  }

  expect_failures = [var.invoker_members]
}

run "the_instance_cap_is_bounded" {
  command = plan

  module {
    source = "./modules/cloud-run-service"
  }

  variables {
    max_instance_count = 0
  }

  expect_failures = [var.max_instance_count]
}

run "no_secret_means_no_secret_access" {
  command = plan

  module {
    source = "./modules/cloud-run-service"
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_binding.runtime_reads_secret) == 0
    error_message = "Without secret_env the runtime identity gets no secret access."
  }

  assert {
    condition     = alltrue([for e in google_cloud_run_v2_service.this.template[0].containers[0].env : length(e.value_source) == 0])
    error_message = "Without secret_env no variable is read from Secret Manager."
  }
}

run "a_secret_is_passed_by_reference_and_only_the_runtime_identity_reads_it" {
  command = plan

  module {
    source = "./modules/cloud-run-service"
  }

  variables {
    secret_env = { OPENAI_API_KEY = "pdf-chatbot-staging-llm-api-key" }
  }

  assert {
    condition = anytrue([
      for e in google_cloud_run_v2_service.this.template[0].containers[0].env :
      e.name == "OPENAI_API_KEY" && e.value == null && length(e.value_source) == 1 &&
      try(e.value_source[0].secret_key_ref[0].secret == "pdf-chatbot-staging-llm-api-key", false) &&
      try(e.value_source[0].secret_key_ref[0].version == "latest", false)
    ])
    error_message = "OPENAI_API_KEY must be a reference to the secret, never a plain value."
  }

  assert {
    condition     = google_secret_manager_secret_iam_binding.runtime_reads_secret["pdf-chatbot-staging-llm-api-key"].role == "roles/secretmanager.secretAccessor"
    error_message = "The grant is read access to the secret value, nothing more."
  }

  assert {
    condition     = google_secret_manager_secret_iam_binding.runtime_reads_secret["pdf-chatbot-staging-llm-api-key"].members == toset(["serviceAccount:pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"])
    error_message = "Only the runtime service account may read the key. The binding is authoritative, so nobody else keeps access."
  }
}
