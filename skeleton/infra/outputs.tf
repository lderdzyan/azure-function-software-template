output "function_app_name" {
  description = "Deployed Azure Function App name."
  value       = one([for function_app in azurerm_linux_function_app.this : function_app.name])
}

output "function_url" {
  description = "Anonymous dummy function endpoint."
  value       = "https://${one([for function_app in azurerm_linux_function_app.this : function_app.default_hostname])}/api/hello"
}

output "function_managed_identity_principal_id" {
  description = "Principal ID of the Function App system-assigned managed identity."
  value       = one([for function_app in azurerm_linux_function_app.this : function_app.identity[0].principal_id])
}
