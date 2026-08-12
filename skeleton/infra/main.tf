resource "random_string" "suffix" {
  for_each = local.function_apps

  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  for_each = local.resource_groups

  name     = each.key
  location = each.value.location
  tags     = each.value.tags
}

resource "azurerm_storage_account" "this" {
  for_each = local.function_apps

  name                            = substr("st${random_string.suffix[each.key].result}${replace(each.value.name_prefix, "-", "")}", 0, 24)
  resource_group_name             = azurerm_resource_group.this[each.value.resource_group_name].name
  location                        = try(each.value.location, null) != null ? each.value.location : local.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = merge(local.default_tags, try(each.value.tags, {}))
}

resource "azurerm_service_plan" "this" {
  for_each = local.function_apps

  name                = "asp-${each.value.name_prefix}-${random_string.suffix[each.key].result}"
  resource_group_name = azurerm_resource_group.this[each.value.resource_group_name].name
  location            = try(each.value.location, null) != null ? each.value.location : local.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = merge(local.default_tags, try(each.value.tags, {}))
}

resource "azurerm_linux_function_app" "this" {
  for_each = local.function_apps

  name                       = "${each.value.name_prefix}-${random_string.suffix[each.key].result}"
  resource_group_name        = azurerm_resource_group.this[each.value.resource_group_name].name
  location                   = try(each.value.location, null) != null ? each.value.location : local.location
  service_plan_id            = azurerm_service_plan.this[each.key].id
  storage_account_name       = azurerm_storage_account.this[each.key].name
  storage_account_access_key = azurerm_storage_account.this[each.key].primary_access_key
  https_only                 = true
  tags                       = merge(local.default_tags, try(each.value.tags, {}))

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"

    application_stack {
      python_version = try(each.value.python_version, "3.12")
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "python"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    ENABLE_ORYX_BUILD              = "true"
  }
}
