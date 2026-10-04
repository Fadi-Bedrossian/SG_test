# Created by scripts/bootstrap-azure.sh
resource_group_name  = "rg-threetier-tfstate"
storage_account_name = "REPLACE_WITH_STATE_ACCOUNT"
container_name       = "tfstate"
key                  = "dev.terraform.tfstate"
use_azuread_auth     = true
