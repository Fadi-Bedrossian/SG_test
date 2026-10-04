# Consumed by .github/workflows/deploy.yml to fill k8s/overlays/<env>/params.env and image names.

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "workload_identity_client_id" {
  value = azurerm_user_assigned_identity.api.client_id
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "ingress_public_ip" {
  description = "Point your DNS A record (APP_HOST) at this address."
  value       = azurerm_public_ip.ingress.ip_address
}

output "k8s_namespace" {
  value = local.namespace
}
