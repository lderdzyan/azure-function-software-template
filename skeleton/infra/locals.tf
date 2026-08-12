locals {
  selected_environment = coalesce(var.config_environment, terraform.workspace)

  available_environments = can(fileset(var.config_root, "*/globals.yaml")) ? sort([
    for globals_file in fileset(var.config_root, "*/globals.yaml") : dirname(globals_file)
  ]) : []

  config_env_root = "${var.config_root}/${local.selected_environment}"
  globals_path    = "${local.config_env_root}/globals.yaml"
  globals         = try(yamldecode(file(local.globals_path)), {})

  environment  = try(local.globals.environment, "")
  location     = try(local.globals.location, "")
  default_tags = try(local.globals.defaults.tags, try(local.globals.tags, {}))

  function_app_glob  = "functionapps/*.yaml"
  function_app_files = can(fileset(local.config_env_root, local.function_app_glob)) ? sort(fileset(local.config_env_root, local.function_app_glob)) : []
  function_apps = {
    for file_name in local.function_app_files :
    trimsuffix(basename(file_name), ".yaml") => yamldecode(file("${local.config_env_root}/${file_name}"))
  }

  resource_groups = {
    for function_app in values(local.function_apps) :
    function_app.resource_group_name => {
      location = try(function_app.location, null) != null ? function_app.location : local.location
      tags     = merge(local.default_tags, try(function_app.tags, {}))
    }
    if try(function_app.resource_group_name, "") != ""
  }
}
