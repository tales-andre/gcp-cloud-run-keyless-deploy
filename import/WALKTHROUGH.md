# Bringing console-made resources under Terraform

The situation: someone at the fictional Acme Supply Co. set up the chatbot by
hand in the Google Cloud console. There is a Cloud Run service, a bucket with
the PDFs and a secret with the AI provider key. Nobody wants to delete and
re-create them, and the next change should be a reviewed pull request, not
another click.

The goal of the first pass is a `terraform plan` that says **No changes**.
Only then does anything get improved, one pull request at a time.

> **Never executed.** This walkthrough and the code in this folder have only
> been through `terraform init -backend=false` and `terraform validate`. An
> import needs a real project, and none was used. The commands and messages
> below are Terraform's and gcloud's documented behavior.

## What you need

- Terraform 1.9 or newer.
- Read access to the project, plus write access to one bucket for the
  Terraform state. Create the state bucket first and turn on object
  versioning, so an earlier state can be recovered.
- Nothing is changed in the project until step 6, and step 6 only writes the
  Terraform state.

## 1. Write down what exists (read-only)

```bash
gcloud run services describe pdf-chatbot --region us-central1 --format=export > live-service.yaml
gcloud storage buckets describe gs://acme-chatbot-docs
gcloud secrets describe openai-api-key
```

`live-service.yaml` is the reference for every value in `main.tf`: the image
digest, the service account the service runs as, environment variables,
volumes, limits and scaling.

## 2. Point Terraform at the state bucket

```bash
cd import
terraform init -backend-config="bucket=acme-chatbot-tfstate" -backend-config="prefix=imported"
```

## 3. Fill in the values

Create `terraform.tfvars` (it is ignored by git):

```hcl
project_id              = "acme-chatbot-production"
bucket_name             = "acme-chatbot-docs"
current_image           = "us-central1-docker.pkg.dev/acme-chatbot-production/cloud-run-source-deploy/pdf-chatbot@sha256:..."
runtime_service_account = "123456789012-compute@developer.gserviceaccount.com"
```

The image and the service account come from `live-service.yaml`. The default
compute service account is what a console deploy usually leaves in place;
replacing it is one of the follow-ups below, not part of the import.

## 4. Plan, and make the code match what is there

```bash
terraform plan
```

The first plan lists the three resources as "will be imported", and probably
some attributes marked `~` (would change). For each one, **change the code to
match the live value**, never the other way round. Repeat until the summary
line is:

```
Plan: 3 to import, 0 to add, 0 to change, 0 to destroy.
```

Where to look first when a value differs:

- Defaults the console set that the code does not mention: request timeout,
  concurrency, execution environment, labels the console added.
- `scaling`: the code keeps the console default of 100 instances on purpose,
  so the import changes nothing.
- The bucket's location and soft-delete settings.

If a resource is hard to write by hand, remove its block from `main.tf` and
let Terraform draft it from the live resource:

```bash
terraform plan -generate-config-out=generated.tf
```

Then tidy `generated.tf` (drop computed and default values) and move the
block back into `main.tf`.

## 5. Check the secret value stays out of state

Only the secret itself is imported, not its versions. The key is never read
by Terraform and never written to the state file. Keep it that way: do not
add a `google_secret_manager_secret_version` resource (the policy check in
`policy/` rejects one).

## 6. Record the import

```bash
terraform apply
```

The summary should read `Apply complete! Resources: 3 imported, 0 added,
0 changed, 0 destroyed.` Nothing changed on Google Cloud; the resources are
now in the Terraform state. Run `terraform plan` once more:

```
No changes. Your infrastructure matches the configuration.
```

The `import` blocks are now no-ops. Delete `imports.tf` in the next pull
request, or keep it as a record.

## 7. Then improve it, one reviewed pull request at a time

Each of these is a small change with its own plan to read:

1. Cap the instances (`max_instance_count`) at what the traffic needs.
2. Give the service its own runtime service account instead of the default
   compute account, with read access to its one secret only.
3. Turn on object versioning on the documents bucket, so a deleted or
   overwritten PDF can be restored.
4. Hand the service over to the modules in `../infra`, so it gets the same
   tests and policy checks as the rest of this repository: import it there
   with `import` blocks that point at the module addresses, then drop it from
   this state with a `removed` block (`lifecycle { destroy = false }`), which
   forgets it without deleting it. `moved` blocks do not work here, because
   the two folders have separate states.
