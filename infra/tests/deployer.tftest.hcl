# The identity GitHub Actions impersonates: three narrow grants and no
# project-level role. (That no service account key exists anywhere is
# checked by the conftest policy in policy/, not here: a test can only
# assert on resources the module has.)

mock_provider "google" {
  source          = "./tests/mocks"
  override_during = plan
}

override_resource {
  target          = module.service.google_service_account.runtime
  override_during = plan
  values = {
    email  = "pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"
    member = "serviceAccount:pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"
    name   = "projects/acme-chatbot-staging/serviceAccounts/pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"
  }
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

run "deployer_can_push_to_one_repository_only" {
  command = plan

  assert {
    condition     = google_artifact_registry_repository_iam_member.deployer_pushes_images.repository == "pdf-chatbot"
    error_message = "The push grant is on the app's repository, not on the project."
  }

  assert {
    condition     = google_artifact_registry_repository_iam_member.deployer_pushes_images.role == "roles/artifactregistry.writer"
    error_message = "Pushing images needs artifactregistry.writer, not admin."
  }

  assert {
    condition     = google_artifact_registry_repository_iam_member.deployer_pushes_images.member == "serviceAccount:pdf-chatbot-ci-stg@acme-chatbot-staging.iam.gserviceaccount.com"
    error_message = "The push grant belongs to the deployer."
  }
}

run "deployer_can_roll_out_one_service_only" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service_iam_member.deployer_rolls_out_revisions.name == "pdf-chatbot-staging"
    error_message = "The deploy grant is on this one service."
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_member.deployer_rolls_out_revisions.role == "roles/run.developer"
    error_message = "Rolling out revisions needs run.developer, not run.admin (which could change who may call the service)."
  }

  assert {
    condition     = google_service_account_iam_member.deployer_runs_as_runtime.service_account_id == "projects/acme-chatbot-staging/serviceAccounts/pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"
    error_message = "The deployer may start revisions as the runtime identity and no other service account."
  }

  assert {
    condition     = google_service_account_iam_member.deployer_runs_as_runtime.role == "roles/iam.serviceAccountUser"
    error_message = "serviceAccountUser on the runtime identity is all a deploy needs."
  }
}

run "production_has_its_own_deployer_and_deploy_variables" {
  command = plan

  variables {
    project_id         = "acme-chatbot-production"
    environment        = "production"
    max_instance_count = 5
    public             = true
    invoker_members    = []
  }

  override_resource {
    target          = module.github.google_service_account.deployer
    override_during = plan
    values = {
      email  = "pdf-chatbot-ci-prd@acme-chatbot-production.iam.gserviceaccount.com"
      member = "serviceAccount:pdf-chatbot-ci-prd@acme-chatbot-production.iam.gserviceaccount.com"
      name   = "projects/acme-chatbot-production/serviceAccounts/pdf-chatbot-ci-prd@acme-chatbot-production.iam.gserviceaccount.com"
    }
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_member.deployer_rolls_out_revisions.member == "serviceAccount:pdf-chatbot-ci-prd@acme-chatbot-production.iam.gserviceaccount.com"
    error_message = "Production is deployed by the production deployer only."
  }

  assert {
    condition = output.github_variables == {
      GCP_PRD_PROJECT      = "acme-chatbot-production"
      GCP_PRD_REGION       = "us-central1"
      GCP_PRD_WIF_PROVIDER = "projects/123456789012/locations/global/workloadIdentityPools/github-mock/providers/github"
      GCP_PRD_DEPLOYER     = "pdf-chatbot-ci-prd@acme-chatbot-production.iam.gserviceaccount.com"
      GCP_PRD_SERVICE      = "pdf-chatbot-production"
      GCP_PRD_REGISTRY     = "us-central1-docker.pkg.dev/acme-chatbot-production/pdf-chatbot"
      GCP_PRD_PUBLIC       = "true"
    }
    error_message = "The output lists exactly the repository variables deploy.yml reads for production."
  }
}
