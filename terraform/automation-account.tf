# create an automation account
resource "azurerm_automation_account" "automation_account" {
  name                = "${var.resource-prefix}-ac"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  sku_name            = "Basic"
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_automation_module" "az-accounts" {
  name                    = "Az.Accounts"
  resource_group_name     = azurerm_resource_group.resource_group.name
  automation_account_name = azurerm_automation_account.automation_account.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/az.accounts/2.13.1"
  }
}

resource "azurerm_automation_module" "az-resourcegraph" {
  depends_on = [ azurerm_automation_module.az-accounts ]
  name                    = "Az.ResourceGraph"
  resource_group_name     = azurerm_resource_group.resource_group.name
  automation_account_name = azurerm_automation_account.automation_account.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.ResourceGraph/0.13.0"
  }
}

resource "azurerm_automation_module" "az-subscription" {
  depends_on = [ azurerm_automation_module.az-accounts ]
  name                    = "Az.Subscription"
  resource_group_name     = azurerm_resource_group.resource_group.name
  automation_account_name = azurerm_automation_account.automation_account.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Subscription/0.10.1"
  }
}

# create a role assignment and assign the role definition to the automation account to the identity of the automation account
resource "azurerm_role_assignment" "role_assignment_sandbox" {
  depends_on = [ azurerm_role_definition.sandbox-automation-account-sandbox ]
  scope                = data.azurerm_management_group.sandbox.id
  role_definition_name = azurerm_role_definition.sandbox-automation-account-sandbox.name
  principal_id         = azurerm_automation_account.automation_account.identity[0].principal_id
}

resource "azurerm_role_assignment" "role_assignment_decomissioned" {
  depends_on = [ azurerm_role_definition.sandbox-automation-account-decomissioned ]
  scope                = data.azurerm_management_group.decomissioned.id
  role_definition_name = azurerm_role_definition.sandbox-automation-account-decomissioned.name
  principal_id         = azurerm_automation_account.automation_account.identity[0].principal_id
}

# main Sandbox Runbook
resource "azurerm_automation_runbook" "example" {
  name                    = "${var.resource-prefix}-ac-lifecycle-runbook"
  location                = azurerm_automation_account.automation_account.location
  resource_group_name     = azurerm_resource_group.resource_group.name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Run book which identifies the expired sandbox subscriptions, removes the privileged roles on the subs, cancels the subscription and move them to decomissioned to management group"
  runbook_type            = "PowerShell"

  publish_content_link {
    uri = var.runbook_uri
  }
}