# Staging for the fictional Acme Supply Co. Replace the project ID and the
# tester group with your own before the first plan.
project_id  = "acme-chatbot-staging"
environment = "staging"
region      = "us-central1"

# Two instances are plenty for testers, and the bill cannot run away.
max_instance_count = 2
min_instance_count = 0

# Private: only these people (and the deployer, for the smoke test) can call it.
public          = false
invoker_members = ["group:chatbot-testers@example.com"]

# Offline mode: no AI provider, no key, nothing leaves the service.
llm_provider = "none"

# Staging can be torn down and rebuilt.
deletion_protection = false
