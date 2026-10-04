environment       = "prod"
location          = "francecentral"
letsencrypt_email = "platform-team@example.com"

aks_sku_tier        = "Standard"
user_node_vm_size   = "Standard_D4ds_v5"
user_node_min_count = 3
user_node_max_count = 6

postgres_sku                   = "GP_Standard_D2ds_v5"
postgres_storage_mb            = 65536
postgres_ha_enabled            = true
postgres_backup_retention_days = 35

# Add your platform admins' Entra group:
# aks_admin_group_object_ids = ["00000000-0000-0000-0000-000000000000"]
