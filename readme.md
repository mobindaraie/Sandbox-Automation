# Azure Sandbox Subscription Lifecycle Manager

This projects provides set of resources to help users manage lifecycles of Azure sandbox subscriptions.

Following the best practices in, [Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/sandbox-environments), a sandbox is an isolated environment where you can test and experiment without affecting other environments, like production, development, or user acceptance testing (UAT) environments.

## Description
This project provides a set of resources to help users manage lifecycles of Azure sandbox subscriptions. The resources are designed to be deployed to an enterprise-scaled zone sandbox management group. The aim of the resources is to clean up and delete sandbox subscriptions upon expiry.

## Table of Contents

- [Pre-requisites](#pre-requisites)
- [Terraform Automation Account and Runbook Creation](#resources)
- [Usage](#usage)
- [Automation Runbook Parameters](#runbook-customisation)
- [Authors](#authors)

## Pre-requisites
- An [implemention](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/enterprise-scale/implementation) of Cloud Adoption Framework Enterprise-Scale Landing Zone
- Terraform installed on your machine
- Azure subscription
- Following Permissions assigned to the principal running the Terraform code:
  - User Access Administrator or Owner role at the 'Sandbox' and 'Cancelled' management group scopes. This role is required to create role definition at the management group scope and assign the role definition to the automation account identity.
  - Permission to create an azure automation account in the subscription.


## Terraform Automation Account and Runbook Creation <a name="resources"></a>

This Terraform code creates an automation account and a runbook in Azure. The runbook is used to identify expired sandbox subscriptions, remove privileged roles on the subscriptions, cancel the subscriptions, and move them to the cancelled management group.

### Usage

1. Clone this repository to your local machine.
2. Navigate to the 'terraform' directory containing the terraform files/
3. Open the terminal and run `terraform init` to initialize the Terraform configuration.
4. Run `terraform plan` to see the resources that will be created.
5. Run `terraform apply` to create the resources.
6. Once the resources are created, you can view the runbook in the Azure portal.

### Resources Created

- `azurerm_automation_account`: Creates an automation account with a system-assigned identity.
- `azurerm_automation_module`: Installs the `Az.Accounts`, `Az.ResourceGraph`, and `Az.Subscription` PowerShell modules.
- `azurerm_role_definition`: Creates a custom role definition to remove privileged roles on the sandbox subscriptions.
- `azurerm_role_assignment`: Assigns the role definition to the automation account identity for the `sandbox` and `cancelled` management groups.
- `azurerm_automation_runbook`: Creates a PowerShell runbook to automate the process of identifying and cancelling expired sandbox subscriptions.

## Runbook Customisation
When the runbook is created in an automation account, all required modules are installed and imported. The runbook is also published. 
The runbook can be customised to suit your needs. For example, you can change the number of days after which a subscription is considered expired. You can also change the management group to which the subscriptions are moved after cancellation.

### Automation Runbook Parameters <a name="runbook-customisation"></a>
The runbook has the following parameters:
- `TopSandboxManagementGroupId`: The ID of the top-level management group in the enterprise-scale landing zone. This is the management group that contains the Sandbox  management groups or Sandbox subscriptions.
- `CancelledManagementGroupId`: The ID of the management group to which the cancelled subscriptions are moved to after subscription cancellation.
- `ExpiryTagKey`: The key of the tag that is used to identify the expiry date of the sandbox subscriptions. The default value is `expiry`. The value of the tag is expected to be in the format `dd/MM/yyyy`.
- `PrivilegedRoles`: A list of privileged roles that are removed from the sandbox subscriptions. The default value is `["Owner", "Contributor", "User Access Administrator"]`.
- `ExcludedPrincipals`: A list of principals that are excluded from the privileged role removal process. The default value is

    `['MS-PIM','Custom Defender for Cloud provisioning Azure Monitor agent','CloudPosture/securityOperators/efenderCSPMSecurityOperator',
  'Azure Monitor Application','StorageAccounts/securityOperators/DefenderForStorageSecurityOperator']`.
- `DisableSubscription`: Specifies whether to disable the subscription before moving it to the cancelled management group. The default value is $true.


## Authors

- [Mobin Daraie](https://github.com/mobindaraie)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
