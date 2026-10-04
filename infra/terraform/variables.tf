variable "subscription_id" {
  description = "Azure subscription to deploy into."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod). Drives naming and sizing."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "francecentral"
}

variable "project" {
  description = "Short project name used in resource names (lowercase letters only)."
  type        = string
  default     = "threetier"
  validation {
    condition     = can(regex("^[a-z]{3,10}$", var.project))
    error_message = "project must be 3-10 lowercase letters."
  }
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}

# ---------- Network ----------
variable "vnet_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.20.0.0/23"
}

variable "postgres_subnet_cidr" {
  description = "Delegated subnet for PostgreSQL Flexible Server. Keep in sync with k8s/base/networkpolicy.yaml."
  type        = string
  default     = "10.20.2.0/24"
}

# ---------- AKS ----------
variable "kubernetes_version" {
  description = "AKS version (null = latest default for the region)."
  type        = string
  default     = null
}

variable "aks_sku_tier" {
  description = "Free for dev, Standard (uptime SLA) for prod."
  type        = string
  default     = "Free"
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_D2ds_v5"
}

variable "user_node_vm_size" {
  type    = string
  default = "Standard_D4ds_v5"
}

variable "user_node_min_count" {
  type    = number
  default = 1
}

variable "user_node_max_count" {
  type    = number
  default = 3
}

variable "aks_admin_group_object_ids" {
  description = "Entra ID groups granted 'Azure Kubernetes Service RBAC Cluster Admin'."
  type        = list(string)
  default     = []
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDRs allowed to reach the Kubernetes API (empty = unrestricted). GitHub-hosted runners need it unrestricted or a self-hosted runner."
  type        = list(string)
  default     = []
}

# ---------- PostgreSQL ----------
variable "postgres_sku" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  type    = number
  default = 32768
}

variable "postgres_ha_enabled" {
  description = "Zone-redundant HA (General Purpose / Memory Optimized SKUs only)."
  type        = bool
  default     = false
}

variable "postgres_backup_retention_days" {
  type    = number
  default = 7
}

# ---------- Ingress / TLS ----------
variable "letsencrypt_email" {
  description = "Contact email for Let's Encrypt (cert-manager ClusterIssuers)."
  type        = string
}

variable "ingress_nginx_chart_version" {
  type    = string
  default = "4.11.3"
}

variable "cert_manager_chart_version" {
  type    = string
  default = "v1.16.2"
}
