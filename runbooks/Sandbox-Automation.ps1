<#
.SYNOPSIS
Cancels sandbox subscriptions that have reached their expiry date.

.DESCRIPTION
The function gets a top management group and a decommissioned management group and moves subscriptions 
to the decommissioned management group if they have reached their expiry date.

.PARAMETER TopSandboxManagementGroupId
Specifies the name of the top management group. The default value is 'Sandbox'.

.PARAMETER decommissionedManagementGroupId
Specifies the name of the decommissioned management group. The default value is 'decommissioned'.

.PARAMETER ExpiryTagKey
Specifies the name of the tag key that contains the expiry date. The default value is 'expiry'.

.PARAMETER GracePeriod
Specifies the grace period in days before cancelling the subscription. The default value is 10.

.PARAMETER AlarmPeriod
Specifies the alarm period in days before the subscription reaches expiry date. The default value is 15.

.PARAMETER PrivilegedRoles
Specifies an array of privileged roles that are included in role assignment removal. The default values are 'Owner', 'Contributor', and 'User Access Administrator'.

.PARAMETER ExcludedPrincipals
Specifies an array of principals that are excluded from the privileged role removals. The default values are 'MS-PIM', 'Custom Defender for Cloud provisioning Azure Monitor agent', 'CloudPosture/securityOperators/DefenderCSPMSecurityOperator', 'Azure Monitor Application', and 'StorageAccounts/securityOperators/DefenderForStorageSecurityOperator'.

.PARAMETER DisableSubscription
Specifies whether to disable the subscription before moving it to the decommissioned management group. The default value is $true.

.INPUTS
None. You can't pipe objects to this function.

.OUTPUTS
None. The function moves subscriptions to the decommissioned management group if they have reached their expiry date.

.EXAMPLE
PS> .\sandbox-automation.ps1 -TopSandboxManagementGroupId 'Sandbox' -decommissionedManagementGroupId 'decommissioned' -ExpiryTagKey 'expiry' -GracePeriod 10 -AlarmPeriod 15 -PrivilegedRoles @('Owner', 'Contributor', 'User Access Administrator') -ExcludedPrincipals @('MS-PIM', 'Custom Defender for Cloud provisioning Azure Monitor agent', 'CloudPosture/securityOperators/DefenderCSPMSecurityOperator', 'Azure Monitor Application', 'StorageAccounts/securityOperators/DefenderForStorageSecurityOperator') -DisableSubscription $true
Moves subscriptions that have reached their expiry date to the 'decommissioned' management group.

.LINK
Readmore: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/sandbox-environments

#>
Param(
  [Parameter(Mandatory = $false, Position = 0)][string]$TopSandboxManagementGroupId = 'Sandbox',
  [Parameter(Mandatory = $false, Position = 1)][string]$decommissionedManagementGroupId = 'cancelled',
  [Parameter(Mandatory = $false, Position = 2)][string]$ExpiryTagKey = 'expiry',
  [Parameter(Mandatory = $false, Position = 3)][int]$GracePeriod = 10,
  [Parameter(Mandatory = $false, Position = 4)][int]$AlarmPeriod = 15,
  [Parameter(Mandatory = $false, Position = 5)][string[]]$PrivilegedRoles = @(
    'Owner',
    'Contributor',
    'User Access Administrator'),
  # list of principals for exclusions
  [Parameter(Mandatory = $false, Position = 6)][string[]]$ExcludedPrincipals = @(
    'MS-PIM',
    'Custom Defender for Cloud provisioning Azure Monitor agent',
    'CloudPosture/securityOperators/DefenderCSPMSecurityOperator',
    'Azure Monitor Application',
    'StorageAccounts/securityOperators/DefenderForStorageSecurityOperator'
  ),
  [Parameter(Mandatory = $false, Position = 7)][bool]$DisableSubscription = $true
)

Write-Output "Connecting using Azure Automation Account Identity"
try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity | Out-Null
    "Connected successfully"
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

$subs = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions'" -ManagementGroup $TopSandboxManagementGroupId

# Checks if the subscription has reached its expiry date and cancels it if it has
function SubscriptionExpiryAssessment() {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]$Subscription,
    [Parameter(Mandatory = $true, Position = 1)][DateTime]$expiryDate
  )

  # Get the current date
  $currentDate = Get-Date

  # Compare the decommission with the current date
  if ($expiryDate.AddDays($GracePeriod) -le $currentDate) {
    Write-Output "Subscription $($Subscription.name) has $ExpiryTagKey tag set to $($expiryDate.ToString("dd-MM-yyyy"))" 
    Write-Output "Cancelling subscription $($Subscription.name)" 
    Write-Output "--------------------------------" 
    SubscriptionRBACCleanUp -Subscription $Subscription
      
    # Disable Azure subscription
    try {
      if ($DisableSubscription) {
        Disable-AzSubscription -Id $Subscription.subscriptionId -Confirm:$false
        Write-Output "Subscription $($Subscription.name) is now disabled! You have 90days to recover disabled subscriptions via Support Ticket."
      }
      else {
        Write-Output "DisableSubscription parameter set to false, skipping subscription cancellation."
      }
    }
    catch {
      Write-Output "Error disabling subscription :$($Subscription.name)`n Error: $($_.Exception.Message)" 
    }

    # Move the subscription to the decommissioned management group
    try {
      New-AzManagementGroupSubscription -GroupId $decommissionedManagementGroupId -SubscriptionId $Subscription.subscriptionId | Out-Null
      Write-Output "Subscription $($Subscription.name) moved to $decommissionedManagementGroupId management group" 
    }
    catch {
      Write-Output "Error moving subscription :$($Subscription.name) to management group $decommissionedManagementGroupId `n Error: $($_.Exception.Message)" 
    }
  }
  else {
    $remainingDays = (New-TimeSpan -Start (Get-Date) -End $expiryDate).Days
    if ($remainingDays -gt 0) {
      if ($remainingDays -le $AlarmPeriod) {
        Write-Output "Subscription $($Subscription.name) is reaching expiry date. Remaining days to expiry: $remainingDays" 
      } else {
        Write-Output "Subscription $($Subscription.name) is valid. Remaining days to expiry: $remainingDays" 
      }
      # TO DO ALARM Function
    } else {
      Write-Output "Subscription $($Subscription.name) has reached expiration date, observing grace period. Remaining days: $($remainingDays+$GracePeriod)" 
    }
  }
}

# lists all role assignments in the subscription and removes them by calling RBACRemoval()
function SubscriptionRBACCleanUp() {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]$Subscription
  )

  $roleAssignments = @()
  Select-AzSubscription -SubscriptionId $sub.subscriptionId | Out-Null
  $resourceGroups = Get-AzResourceGroup
    
  foreach ($resourceGroup in $resourceGroups) {
    $roleAssignments += Get-AzRoleAssignment -ResourceGroupName $resourceGroup.ResourceGroupName
  }
  $roleAssignments = $roleAssignments | Sort-Object * -Unique
  $roleAssignments = $roleAssignments | Where-Object { $_.Scope -notlike "*/providers/Microsoft.Management/managementGroups/*" -and $_.Scope -ne "/" }
  if ($roleAssignments) {
    RBACRemoval -roleAssignments $roleAssignments
  }
  else {
    Write-Output "Subscription $($Subscription.name) has no role assignments." 
  }
}

# Removes privileged role assignments
function RBACRemoval() {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]$roleAssignments
  )
  Write-Output "Removing Privileged RBAC assignments" 
  foreach ($roleAssignment in $roleAssignments) {
    if ($roleAssignment.RoleDefinitionName -in $PrivilegedRoles) {
      if ($roleAssignment.DisplayName -notin $ExcludedPrincipals) {
        try {
          Get-AzRoleAssignment -ObjectId $roleAssignment.ObjectId -RoleDefinitionId $roleAssignment.RoleDefinitionId | Remove-AzRoleAssignment 
        }
        catch {
          Write-Output "Error removing role assignment $($roleAssignment.DisplayName)`n($_.Exception.Message)" 
          continue
        }
      }
    }
  }
  Write-Output "Privileged RBAC assignments removed"  
}

# Loop through all subscriptions and identify the ones that have $expiryDate tag and then call SubscriptionExpiryAssessment()
foreach ($sub in $subs) {
  # Select the subscription
  Select-AzSubscription -SubscriptionId $sub.subscriptionId | Out-Null
  
  # Get the tag "expiry" on the subscription
  $expiryDate = $null;
  try {
    $expiryString = (Get-AzTag -ResourceId $sub.ResourceId).Properties.TagsProperty[$ExpiryTagKey]
    $expiryDate = [DateTime]::ParseExact($expiryString, "dd/MM/yyyy", $null).Date
  }
  catch {
    Write-Output "Error getting expiry tag from subscription $($sub.name)" 
    continue
  }

  if ($expiryDate) {
    try {
      SubscriptionExpiryAssessment -Subscription $sub -expiryDate $expiryDate
    }
    catch {
      Write-Output "Error Performing clean up activities on subscription:$($sub.name) `n Error: $($_.Exception.Message)" 
      continue
    }
  }
}