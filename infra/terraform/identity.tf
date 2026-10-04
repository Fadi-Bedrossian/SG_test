# Workload identity for the API pods: Kubernetes ServiceAccount <-> Azure managed identity.
resource "azurerm_user_assigned_identity" "api" {
  name                = "id-api-${local.name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "api" {
  name                = "fic-api-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.api.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject             = "system:serviceaccount:${local.namespace}:api" # k8s/base/serviceaccount.yaml
}

resource "azurerm_role_assignment" "api_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}
