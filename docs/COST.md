# What this setup costs, and what makes the bill grow

There is no total on this page on purpose. The bill depends on your traffic,
and prices change. What you get instead: what each service charges for, what
makes that line grow, and which setting in this repository keeps it in check.
Put your own traffic into the
[Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator)
before anything is created.

The descriptions below come from Google's public pricing pages, read on
7 November 2026. The pages win if anything here is out of date.

## Cloud Run (the chatbot)

Source: [Cloud Run pricing](https://cloud.google.com/run/pricing).

**What it charges for.** CPU and memory while an instance is billable, plus a
fee per request, with a monthly free tier. Billable time is rounded up to the
nearest 100 milliseconds.

This setup uses *request-based billing* (`cpu_idle = true` in
`infra/modules/cloud-run-service`). An instance is billed while it starts,
while it shuts down and while at least one request is being handled. The
pricing page says idle instances that are not minimum instances are not
charged, and requests denied by IAM are not billed.

**What makes it grow, and what keeps it in check here:**

| Grows with | In this repository |
|---|---|
| Number of instances running at once | `max_instance_count` caps it (2 in staging, 5 in production). Past the cap, requests wait or fail instead of starting another billed instance. The tests refuse 0 and anything above 20. |
| Instances kept warm | `min_instance_count = 0`: the service scales to zero when nobody uses it. A warm instance avoids a cold start but is billed while idle. |
| How long each request takes | Offline mode answers from an in-memory index and calls no model. With an AI provider, each answered question waits for the model, so instance time per request goes up. |
| Memory and CPU per instance | 512 MiB and 1 vCPU. Check the real need with `docker stats` on your own documents before lowering or raising it. |
| Requests per instance | `concurrency = 20`: requests share an instance instead of each one starting its own. |
| Outbound data | Responses are small JSON and the PDFs it serves. Internet egress is billed per GiB after a small free amount. |
| Strangers calling staging | Staging is private. Calls without permission are rejected by IAM and, per the pricing page, not billed. |

A rough way to estimate billable instance time for one month:
*requests × average seconds per request ÷ requests handled at once*. Multiply
it by the vCPU and memory prices for your region, add the per-request fee,
and subtract the free tier.

## Artifact Registry (the images)

Source: [Artifact Registry pricing](https://cloud.google.com/artifact-registry/pricing).

**What it charges for.** Stored data (GB per month, after a free amount
shared across your billing account), data transfer, and vulnerability
scanning if you turn it on.

**What makes it grow:** every pushed image stays until it is deleted, and
pulls from another region count as cross-region transfer.

**Here:** the cleanup policy keeps the 10 most recent images (so rollback
targets are never removed) and deletes anything older than 30 days. The
repository is in the same region as Cloud Run, which is what Google's page
recommends to avoid cross-region transfer. Scanning is not turned on.

## Secret Manager (the AI provider key)

Source: [Secret Manager pricing](https://cloud.google.com/secret-manager/pricing).

**What it charges for.** Active secret versions per month and access
operations, each with a free amount.

**Here:** offline mode creates no secret at all. With an AI provider there is
one secret. Cloud Run reads it when an instance starts, not on every request,
so access operations follow the number of instance starts. Destroy old
versions after a key rotation; destroyed versions are free.

## Cloud SQL (optional, off by default)

Source: [Cloud SQL pricing](https://cloud.google.com/sql/pricing).

**What it charges for.** The instance for every hour it runs (CPU and memory,
or a shared-core machine type), storage, backups, network egress and, for
high availability, a second instance.

**What makes it grow:** a database is billed around the clock whether or not
anyone uses the app, and there is no scale to zero. `REGIONAL` (high
availability) is charged at the higher HA prices. Storage grows on its own
when the disk fills.

**Here:** the chatbot needs no database, so `cloud_sql` is `null` in both
environments and nothing is billed. If you turn it on, the module starts on
the small shared-core `db-f1-micro` (no SLA), `ZONAL`, with automatic disk
growth capped by `disk_autoresize_limit_gb`.

## Things this repository does not add to the bill

- No load balancer, Cloud Armor or Cloud CDN. Cloud Run serves HTTPS on its own
  `run.app` address. Your own domain in production needs a front door, and
  Google recommends a global external Application Load Balancer, which is
  billed separately (see [CUTOVER.md](CUTOVER.md)). It is not created here.
- No monitoring or alerting setup. Cloud Run sends request logs to Cloud
  Logging on its own; check the
  [Cloud Logging pricing](https://cloud.google.com/stackdriver/pricing) if
  traffic is high.
- No budget alert. The instance cap is the guard against a runaway bill. A
  budget alert in the Billing console is still a good idea, but it only
  sends an email; it does not stop anything.

## Outside Google Cloud

- **AI provider** (when `llm_provider` is not `none`): the provider bills per
  token for each answered question. A refused question never calls the model.
- **GitHub Actions**: the workflows run on GitHub's hosted runners and the
  image is kept in GitHub Container Registry. For a public repository these
  are covered by GitHub's free allowance; check your plan for a private one.
