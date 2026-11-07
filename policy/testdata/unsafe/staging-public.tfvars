# Deliberately unsafe: the policy check must reject this file.
project_id         = "acme-chatbot-staging"
environment        = "staging"
max_instance_count = 2
public             = true
invoker_members    = ["allAuthenticatedUsers"]
