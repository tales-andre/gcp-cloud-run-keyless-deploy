# One environment (staging or production) per state. Apply it from your own
# machine after reading the plan:
#   terraform init -backend-config=envs/staging.gcs.tfbackend
#   terraform plan -var-file=envs/staging.tfvars -out=staging.plan
# The GitHub workflow never runs Terraform; it only ships new images.

locals {
  service_name = "${var.app_name}-${var.environment}"
  env_short    = var.environment == "production" ? "prd" : "stg"

  # Which environment variable each provider reads its key from (see the
  # chatbot's .env.example).
  llm_key_variable = {
    openai    = "OPENAI_API_KEY"
    anthropic = "ANTHROPIC_API_KEY"
    gemini    = "GOOGLE_API_KEY"
  }
  llm_needs_key = var.llm_provider != "none"

  apis = concat(
    [
      "artifactregistry.googleapis.com",
      "iam.googleapis.com",
      "iamcredentials.googleapis.com",
      "run.googleapis.com",
      "secretmanager.googleapis.com",
      "sts.googleapis.com",
    ],
    var.cloud_sql == null ? [] : [
      "compute.googleapis.com",
      "servicenetworking.googleapis.com",
      "sqladmin.googleapis.com",
    ],
  )
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  project = var.project_id
  service = each.value
  # Turning an API off on destroy can break other things in the project.
  disable_on_destroy = false
}

module "registry" {
  source = "./modules/artifact-registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = var.app_name

  depends_on = [google_project_service.apis]
}

# The AI provider key, when one is used. Terraform creates the empty secret;
# you add the value yourself, so it never passes through Terraform state:
#   printf '%s' "$KEY" | gcloud secrets versions add <secret_id> --data-file=-
resource "google_secret_manager_secret" "llm_api_key" {
  count = local.llm_needs_key ? 1 : 0

  project   = var.project_id
  secret_id = "${local.service_name}-llm-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

module "cloud_sql" {
  source = "./modules/cloud-sql"
  count  = var.cloud_sql == null ? 0 : 1

  project_id                    = var.project_id
  region                        = var.region
  name                          = "${local.service_name}-db"
  network_id                    = var.cloud_sql.network_id
  tier                          = var.cloud_sql.tier
  availability_type             = var.cloud_sql.availability_type
  create_private_service_access = var.cloud_sql.create_private_service_access
  runtime_service_account_email = module.service.runtime_service_account_email
  deletion_protection           = var.deletion_protection

  depends_on = [google_project_service.apis]
}

module "service" {
  source = "./modules/cloud-run-service"

  project_id          = var.project_id
  region              = var.region
  name                = local.service_name
  image               = var.image
  max_instance_count  = var.max_instance_count
  min_instance_count  = var.min_instance_count
  cpu                 = var.cpu
  memory              = var.memory
  deletion_protection = var.deletion_protection
  public              = var.public
  labels              = { app = var.app_name, environment = var.environment }

  # Staging is private. The deployer may call it so the post-deploy smoke
  # test can run with an identity token; production gets no such grant.
  invoker_members = concat(
    var.invoker_members,
    var.environment == "staging" ? [module.github.deployer_member] : [],
  )

  env = merge(
    { LLM_PROVIDER = var.llm_provider },
    local.llm_needs_key && var.llm_model != "" ? { LLM_MODEL = var.llm_model } : {},
    var.cloud_sql == null ? {} : {
      INSTANCE_CONNECTION_NAME = module.cloud_sql[0].connection_name
      DB_NAME                  = module.cloud_sql[0].database_name
      DB_IAM_USER              = module.cloud_sql[0].iam_user
    },
  )

  secret_env = local.llm_needs_key ? {
    (local.llm_key_variable[var.llm_provider]) = google_secret_manager_secret.llm_api_key[0].secret_id
  } : {}

  # With a database, the app connects with the Cloud SQL connector over the
  # VPC (private IP, IAM login), so the service needs direct VPC egress.
  vpc_access = var.cloud_sql == null ? null : {
    network    = var.cloud_sql.network_id
    subnetwork = var.cloud_sql.subnetwork_id
  }

  depends_on = [google_project_service.apis]
}

module "github" {
  source = "./modules/github-wif"

  project_id           = var.project_id
  pool_id              = "github-${var.environment}"
  github_repository    = var.github_repository
  github_repository_id = var.github_repository_id
  branch               = var.github_branch
  github_environment   = var.environment
  deployer_account_id  = "${var.app_name}-ci-${local.env_short}"

  depends_on = [google_project_service.apis]
}

# What the deployer may do, and nothing more: push images to this one
# repository, roll out new revisions of this one service, and start them as
# the runtime identity. No project-level role.
resource "google_artifact_registry_repository_iam_member" "deployer_pushes_images" {
  project    = var.project_id
  location   = var.region
  repository = module.registry.repository_id
  role       = "roles/artifactregistry.writer"
  member     = module.github.deployer_member
}

resource "google_cloud_run_v2_service_iam_member" "deployer_rolls_out_revisions" {
  project  = var.project_id
  location = var.region
  name     = module.service.name
  role     = "roles/run.developer"
  member   = module.github.deployer_member
}

resource "google_service_account_iam_member" "deployer_runs_as_runtime" {
  service_account_id = module.service.runtime_service_account_name
  role               = "roles/iam.serviceAccountUser"
  member             = module.github.deployer_member
}
