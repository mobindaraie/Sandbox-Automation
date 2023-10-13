resource "azurerm_role_definition" "sandbox-automation-account-sandbox" {
  name        = "Sandbox Automation - Sandbox MG"
  scope       = data.azurerm_management_group.sandbox.id
  description = "Custom Least Privileged Role Definition which allows for Automation Account for Samdbox Management Group"
  permissions {
    actions = [
      "*/read",
      "Microsoft.Management/managementGroups/delete",
      "Microsoft.Management/managementGroups/read",
      "Microsoft.Management/managementGroups/subscriptions/delete",
      "Microsoft.Management/managementGroups/subscriptions/write",
      "Microsoft.Management/managementGroups/write",
      "Microsoft.Management/managementGroups/subscriptions/read",
      "Microsoft.Authorization/*/read",
      "Microsoft.Authorization/roleAssignments/*",
      "Microsoft.Subscription/cancel/action"
    ]
    not_actions = []
  }
  assignable_scopes = [
    data.azurerm_management_group.sandbox.id]
}


# create an azure role definition
resource "azurerm_role_definition" "sandbox-automation-account-cancelled" {
  name        = "Sandbox Automation - Cancelled MG"
  scope       = data.azurerm_management_group.cancelled.id
  description = "Custom Least Privileged Role Definition which allows for Automation Account for Cancelled Management Group"
  permissions {
    actions = [
      "*/read",
      "Microsoft.Management/managementGroups/delete",
      "Microsoft.Management/managementGroups/read",
      "Microsoft.Management/managementGroups/subscriptions/delete",
      "Microsoft.Management/managementGroups/subscriptions/write",
      "Microsoft.Management/managementGroups/write",
      "Microsoft.Management/managementGroups/subscriptions/read"
    ]
    not_actions = []
  }
  assignable_scopes = [
    data.azurerm_management_group.cancelled.id]
}

# another role definition
resource "azurerm_role_definition" "sandbox_users" {
  name        = "Sandbox Users"
  scope       = data.azurerm_management_group.sandbox.id
  description = "Privileged User role definition for Sandbox users which allow them to action everything in the subcription except delete the subscription tags"
  permissions {
    actions = [
      "*"
    ]
    not_actions = [
          "Microsoft.Resources/subscriptions/tagNames/write",
          "Microsoft.Resources/subscriptions/tagNames/delete",
          "Microsoft.Resources/subscriptions/tagNames/tagValues/write",
          "Microsoft.Resources/subscriptions/tagNames/tagValues/delete",
          "Microsoft.Subscription/cancel/action"
    ]
  }
  assignable_scopes = [
    data.azurerm_management_group.sandbox.id]
}
