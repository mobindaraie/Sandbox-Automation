resource "azurerm_role_definition" "sandbox-automation-account-sandbox" {
  name        = "${var.resource-prefix}-sandbox-mg-rd"
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
      "Microsoft.Management/register/action",
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
resource "azurerm_role_definition" "sandbox-automation-account-decommissioned" {
  name        = "${var.resource-prefix}-decommissioned-mg-rd"
  scope       = data.azurerm_management_group.decommissioned.id
  description = "Custom Least Privileged Role Definition which allows for Automation Account for decommissioned Management Group"
  permissions {
    actions = [
      "*/read",
      "Microsoft.Management/managementGroups/delete",
      "Microsoft.Management/managementGroups/read",
      "Microsoft.Management/managementGroups/subscriptions/delete",
      "Microsoft.Management/managementGroups/subscriptions/write",
      "Microsoft.Management/managementGroups/write",
      "Microsoft.Management/managementGroups/subscriptions/read",
      "Microsoft.Authorization/roleAssignments/*",
      "Microsoft.Management/register/action"
    ]
    not_actions = []
  }
  assignable_scopes = [
    data.azurerm_management_group.decommissioned.id]
}

# another role definition
resource "azurerm_role_definition" "sandbox_users" {
  name        = "${var.resource-prefix}-users-rd"
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
