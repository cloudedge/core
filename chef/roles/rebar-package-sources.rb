name "rebar-package-sources"
description "Set up repositories to point where the provisioner wants them to go"
run_list(
         "recipe[repos]"
)
