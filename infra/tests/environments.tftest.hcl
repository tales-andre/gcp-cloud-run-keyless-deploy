# The root module as each environment uses it: staging can never be public,
# the instance cap is always there, and the AI key only exists when an AI
# provider is switched on. Mock provider only.

mock_provider "google" {
  source          = "./tests/mocks"
  override_during = plan
}

override_resource {
  target          = module.github.google_service_account.deployer
  override_during = plan
  values = {
    email  = "pdf-chatbot-ci-stg@acme-chatbot-staging.iam.gserviceaccount.com"
    member = "serviceAccount:pdf-chatbot-ci-stg@acme-chatbot-staging.iam.gserviceaccount.com"
    name   = "projects/acme-chatbot-staging/serviceAccounts/pdf-chatbot-ci-stg@acme-chatbot-staging.iam.gserviceaccount.com"
  }
}

variables {
  project_id         = "acme-chatbot-staging"
  environment        = "staging"
  max_instance_count = 2
  invoker_members    = ["group:chatbot-testers@example.com"]
}

run "staging_is_private" {
  command = plan

  assert {
    condition     = length(setintersection(toset(output.invokers), toset(["allUsers", "allAuthenticatedUsers"]))) == 0
    error_message = "Staging must not be callable by allUsers or allAuthenticatedUsers."
  }

  assert {
    condition     = toset(output.invokers) == toset(["group:chatbot-testers@example.com", "serviceAccount:pdf-chatbot-ci-stg@acme-chatbot-staging.iam.gserviceaccount.com"])
    error_message = "Staging callers are the tester group and the deployer (for the post-deploy smoke test), nobody else."
  }

  assert {
    condition     = output.max_instance_count == 2
    error_message = "The staging cap must reach the service."
  }
}

run "staging_cannot_be_made_public" {
  command = plan

  variables {
    public = true
  }

  expect_failures = [var.public]
}

run "allusers_cannot_sneak_in_through_the_member_list" {
  command = plan

  variables {
    invoker_members = ["allUsers"]
  }

  expect_failures = [var.invoker_members]
}

run "the_instance_cap_cannot_be_zero" {
  command = plan

  variables {
    max_instance_count = 0
  }

  expect_failures = [var.max_instance_count]
}

run "the_instance_cap_cannot_be_huge" {
  command = plan

  variables {
    max_instance_count = 100
  }

  expect_failures = [var.max_instance_count]
}

run "production_is_public_only_on_purpose_and_the_deployer_cannot_call_it" {
  command = plan

  variables {
    project_id         = "acme-chatbot-production"
    environment        = "production"
    max_instance_count = 5
    public             = true
    invoker_members    = []
  }

  assert {
    condition     = output.invokers == tolist(["allUsers"])
    error_message = "With public = true, allUsers is the only invoker; the deployer gets no invoker role in production."
  }
}

run "production_stays_private_without_public" {
  command = plan

  variables {
    project_id         = "acme-chatbot-production"
    environment        = "production"
    max_instance_count = 5
    invoker_members    = []
  }

  assert {
    condition     = length(output.invokers) == 0
    error_message = "public defaults to false, also in production."
  }
}

run "offline_mode_creates_no_secret" {
  command = plan

  assert {
    condition     = length(google_secret_manager_secret.llm_api_key) == 0
    error_message = "Offline mode must not create a secret."
  }

  assert {
    condition     = length(module.service.secret_env_names) == 0
    error_message = "Offline mode reads nothing from Secret Manager."
  }

  assert {
    condition     = output.llm_api_key_secret == null
    error_message = "Offline mode has no key to add."
  }
}

run "an_ai_provider_gets_its_key_from_secret_manager" {
  command = plan

  variables {
    llm_provider = "gemini"
    llm_model    = "example-model"
  }

  assert {
    condition     = google_secret_manager_secret.llm_api_key[0].secret_id == "pdf-chatbot-staging-llm-api-key"
    error_message = "An AI provider needs its key secret."
  }

  assert {
    condition     = module.service.secret_env_names == tolist(["GOOGLE_API_KEY"])
    error_message = "Gemini reads GOOGLE_API_KEY, and it must come from Secret Manager."
  }

  assert {
    condition     = length(google_secret_manager_secret.llm_api_key[0].replication) == 1
    error_message = "The secret needs a replication policy."
  }
}

run "no_database_unless_asked" {
  command = plan

  assert {
    condition     = length(module.cloud_sql) == 0
    error_message = "The chatbot needs no database, so none is created by default."
  }
}
