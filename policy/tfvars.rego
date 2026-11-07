# Rules for the environment files in infra/envs/*.tfvars.

package main

import rego.v1

is_environment_file if input.environment

deny contains "staging must not be public: set public = false" if {
	input.environment == "staging"
	input.public == true
}

deny contains msg if {
	input.environment == "staging"
	some member in input.invoker_members
	member in public_principals
	msg := sprintf("staging must not list %s in invoker_members", [member])
}

deny contains msg if {
	is_environment_file
	not input.max_instance_count
	msg := sprintf("%s must set max_instance_count: the cap is the protection against a runaway bill", [input.environment])
}

deny contains msg if {
	is_environment_file
	input.max_instance_count > 20
	msg := sprintf("%s: max_instance_count %d is above 20", [input.environment, input.max_instance_count])
}
