resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.project}-${var.environment}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = var.environment == "prod"
  tags                       = local.tags
}

# Terraform (CI identity) writes the database secrets.
resource "azurerm_role_assignment" "deployer_kv_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

locals {
  db_secrets = {
    "pg-host"     = azurerm_postgresql_flexible_server.main.fqdn
    "pg-user"     = azurerm_postgresql_flexible_server.main.administrator_login
    "pg-password" = random_password.postgres.result
  }
}

resource "azurerm_key_vault_secret" "db" {
  for_each     = local.db_secrets
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [azurerm_role_assignment.deployer_kv_officer]
}

resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "diag-keyvault"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
  }
}
