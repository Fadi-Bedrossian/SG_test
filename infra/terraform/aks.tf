resource "azurerm_kubernetes_cluster" "aks" {
  name                      = "aks-${local.name}"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  dns_prefix                = local.name
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = var.aks_sku_tier
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # Identity & access
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  local_account_disabled    = true
  azure_policy_enabled      = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = var.aks_admin_group_object_ids
  }

  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # System pool runs only critical add-ons; app workloads land on the user pool below.
  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    vnet_subnet_id               = azurerm_subnet.aks.id
    zones                        = ["1", "2", "3"]
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 3
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "systemtmp"
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 64

    upgrade_settings {
      max_surge = "33%"
    }
  }

  # Azure CNI overlay + Cilium: enforces the NetworkPolicies in k8s/base/networkpolicy.yaml.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
    load_balancer_sku   = "standard"
  }

  # Azure Key Vault provider for the Secrets Store CSI driver.
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.main.id
    msi_auth_for_monitoring_enabled = true
  }

  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  tags = local.tags

  lifecycle {
    ignore_changes = [
      kubernetes_version, # managed by automatic_upgrade_channel
      default_node_pool[0].node_count,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  mode                  = "User"
  vm_size               = var.user_node_vm_size
  vnet_subnet_id        = azurerm_subnet.aks.id
  zones                 = ["1", "2", "3"]
  auto_scaling_enabled  = true
  min_count             = var.user_node_min_count
  max_count             = var.user_node_max_count
  os_disk_type          = "Ephemeral"
  os_disk_size_gb       = 64

  upgrade_settings {
    max_surge = "33%"
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [node_count]
  }
}

# ---------- Role assignments ----------

# Nodes pull images from ACR without credentials.
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.main.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Control plane manages the LB, the static ingress IP and the custom subnet.
resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Whoever runs Terraform (CI's OIDC identity) can install Helm releases and deploy manifests.
resource "azurerm_role_assignment" "deployer_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}
