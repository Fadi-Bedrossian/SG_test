environment       = "dev"
location          = "francecentral"
letsencrypt_email = "platform-team@example.com"

aks_sku_tier        = "Free"
user_node_vm_size   = "Standard_D2ds_v5"
user_node_min_count = 1
user_node_max_count = 2

postgres_sku                   = "B_Standard_B1ms"
postgres_ha_enabled            = false
postgres_backup_retention_days = 7

# subscription_id comes from TF_VAR_subscription_id (GitHub secret AZURE_SUBSCRIPTION_ID).
