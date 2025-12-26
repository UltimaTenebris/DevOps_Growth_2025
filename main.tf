terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # Requirement 8: Remote Backend
  backend "azurerm" {
    resource_group_name  = "rg-bestrong-state"
    storage_account_name = "stbestrongstate" # Must be unique globally
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group 
resource "azurerm_resource_group" "rg" {
  name     = "rg-bestrong-prod-001"
  location = var.location
}

# Requirement 5: Private Network 
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-bestrong-prod"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet for Private Endpoints (Data, KeyVault)
resource "azurerm_subnet" "snet_private" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet for App Service Integration (Delegated)
resource "azurerm_subnet" "snet_app" {
  name                 = "snet-app-service"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Requirement 3: Container Registry 
resource "azurerm_container_registry" "acr" {
  name                = "acrbestrong${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium" # Required for Private Link. Standard is cheaper but public endpoint remains.
  admin_enabled       = false     # Requirement: No passwords/admin user
  public_network_access_enabled = false 
}

# Requirement 4: Key Vault 
resource "azurerm_key_vault" "kv" {
  name                        = "kv-bestrong-${random_string.suffix.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  public_network_access_enabled = false

  sku_name = "standard"
  
  # Use RBAC for modern access control
  enable_rbac_authorization = true
}

# Requirement 6: SQL Database 
resource "azurerm_mssql_server" "sql" {
  name                         = "sql-bestrong-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "db" {
  name      = "sqldb-bestrong-prod"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "S0"
}

# Requirement 7: Storage for Files 
resource "azurerm_storage_account" "st" {
  name                     = "stbestrongapp${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = false 
}

resource "azurerm_storage_share" "fs" {
  name                 = "appdata"
  storage_account_name = azurerm_storage_account.st.name
  quota                = 50
}

# Requirement 1: App Service (Backend)
resource "azurerm_service_plan" "plan" {
  name                = "plan-bestrong-linux"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-bestrong-backend"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id

  # Connect to the VNet
  virtual_network_subnet_id = azurerm_subnet.snet_app.id

  # Identity "Introduce itself"
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      docker_image     = "${azurerm_container_registry.acr.login_server}/myapp"
      docker_image_tag = "latest"
    }
    
    # Mount the Azure Files
    storage_account {
      account_name = azurerm_storage_account.st.name
      access_key   = azurerm_storage_account.st.primary_access_key
      name         = "user_files_mount"
      share_name   = azurerm_storage_share.fs.name
      type         = "AzureFiles"
      mount_path   = "/mnt/userfiles"
    }
  }
  
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.appinsights.instrumentation_key
  }
}

# Requirement 2: Logs 
resource "azurerm_application_insights" "appinsights" {
  name                = "appi-bestrong"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

# Identity & Access (Connecting the dots) 

# 1. Give App permission to pull from ACR
resource "azurerm_role_assignment" "acrpull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# 2. Give App permission to read secrets from Key Vault
resource "azurerm_role_assignment" "kvreader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# Private Endpoints (The "Private Territory" glue)

resource "azurerm_private_endpoint" "sql_pe" {
  name                = "pe-sql-bestrong"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_private.id

  private_service_connection {
    name                           = "sql-privatelink"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }
}

# Utilities
data "azurerm_client_config" "current" {}
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}