check "globals_file_exists" {
  assert {
    condition     = fileexists(local.globals_path)
    error_message = "No globals.yaml found for environment '${local.selected_environment}'. Expected ${local.globals_path}. Available environments: ${join(", ", local.available_environments)}"
  }
}

check "globals_required_fields" {
  assert {
    condition = alltrue([
      local.environment != "",
      local.location != "",
      local.environment == local.selected_environment
    ])
    error_message = "globals.yaml must define environment and location, and environment must match the selected folder name."
  }
}

check "single_function_app_file" {
  assert {
    condition     = length(local.function_app_files) == 1
    error_message = "Exactly one Function App YAML file is required under ${local.config_env_root}/functionapps."
  }
}

check "function_app_required_fields" {
  assert {
    condition = alltrue([
      for function_app in values(local.function_apps) : alltrue([
        try(function_app.name_prefix, "") != "",
        try(function_app.resource_group_name, "") != ""
      ])
    ])
    error_message = "Each Function App YAML file must define name_prefix and resource_group_name."
  }
}

check "function_app_name_prefix" {
  assert {
    condition = alltrue([
      for function_app in values(local.function_apps) :
      length(try(function_app.name_prefix, "")) <= 40 &&
      can(regex("^[a-z0-9](?:[a-z0-9-]{0,38}[a-z0-9])?$", try(function_app.name_prefix, "")))
    ])
    error_message = "Each name_prefix must be 1-40 lowercase letters, numbers, or hyphens, and cannot start or end with a hyphen."
  }
}
