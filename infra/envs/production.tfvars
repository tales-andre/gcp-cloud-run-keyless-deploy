# Production for the fictional Acme Supply Co. Replace the project ID before
# the first plan.
project_id  = "acme-chatbot-production"
environment = "production"
region      = "us-central1"

# The cap is the cost guard: past 5 busy instances, requests wait instead of
# new instances being added.
max_instance_count = 5
min_instance_count = 0

# The sample documents are public customer help pages, so the chatbot is open
# to everyone. For internal documents set public = false and use
# invoker_members or Identity-Aware Proxy instead.
public = true

# Start offline. To switch on an AI provider: set llm_provider and llm_model,
# apply, then add the key to the secret named in the llm_api_key_secret output.
llm_provider = "none"
llm_model    = ""

deletion_protection = true
