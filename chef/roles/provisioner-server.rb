
name "provisioner-server"
description "Provisioner Server role - Apt and Networking"
run_list(
         "recipe[utils]",
         "recipe[provisioner::servers]"
)
default_attributes()
override_attributes()
