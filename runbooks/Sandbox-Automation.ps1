<#
.SYNOPSIS
Cancels sandbox subscriptions that have reached their expiry date.

.DESCRIPTION
The function gets a top management group and a cancelled management group and moves subscriptions 
to the cancelled management group if they have reached their expiry date.

.PARAMETER TopSandboxManagementGroupId
Specifies the name of the top management group. The default value is 'Sandbox'.

.PARAMETER CancelledManagementGroupId
Specifies the name of the cancelled management group. The default value is 'cancelled'.

.PARAMETER ExpiryTagKey
Specifies the name of the tag key that contains the expiry date. The default value is 'expiry'.

.PARAMETER privilegedroles
Specifies an array of privileged roles that are excluded from the cancellation process. The default values are 'Owner', 'Contributor', and 'User Access Administrator'.

.PARAMETER excludedPrincipals
Specifies an array of principals that are excluded from the cancellation process. The default values are 'MS-PIM', 'Custom Defender for Cloud provisioning Azure Monitor agent', 'CloudPosture/securityOperators/DefenderCSPMSecurityOperator', 'Azure Monitor Application', and 'StorageAccounts/securityOperators/DefenderForStorageSecurityOperator'.

.INPUTS
None. You can't pipe objects to this function.

.OUTPUTS
None. The function moves subscriptions to the cancelled management group if they have reached their expiry date.

.EXAMPLE
PS> .\sandbox-automation.ps1 -TopSandboxManagementGroupId 'Sandbox' -CancelledManagementGroupId 'cancelled' -ExpiryTagKey 'expiry' -privilegedroles @('Owner', 'Contributor', 'User Access Administrator') -excludedPrincipals @('MS-PIM', 'Custom Defender for Cloud provisioning Azure Monitor agent', 'CloudPosture/securityOperators/DefenderCSPMSecurityOperator', 'Azure Monitor Application', 'StorageAccounts/securityOperators/DefenderForStorageSecurityOperator')
Moves subscriptions that have reached their expiry date to the 'cancelled' management group.

.LINK
Readmore: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/sandbox-environments

#>
Param(
  [Parameter(Mandatory = $false, Position = 0)][string]$TopSandboxManagementGroupId = 'Sandbox',
  [Parameter(Mandatory = $false, Position = 1)][string]$CancelledManagementGroupId = 'cancelled',
  [Parameter(Mandatory = $false, Position = 2)][string]$ExpiryTagKey = 'expiry',
  [Parameter(Mandatory = $false, Position = 4)][int]$GracePeriod = 10,
  [Parameter(Mandatory = $false, Position = 5)][int]$AlarmPeriod = 15,
  [Parameter(Mandatory = $false, Position = 6)][string[]]$privilegedroles = @(
    'Owner',
    'Contributor',
    'User Access Administrator'),
  # list of principals for exclusions
  [Parameter(Mandatory = $false, Position = 7)][string[]]$excludedPrincipals = @(
    'MS-PIM',
    'Custom Defender for Cloud provisioning Azure Monitor agent',
    'CloudPosture/securityOperators/DefenderCSPMSecurityOperator',
    'Azure Monitor Application',
    'StorageAccounts/securityOperators/DefenderForStorageSecurityOperator'
  )
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

  # Compare the decomission with the current date
  if ($expiryDate.AddDays($GracePeriod) -le $currentDate) {
    Write-Host "Subscription $($Subscription.name) has $ExpiryTagKey tag set to $($expiryDate.ToString("dd-MM-yyyy"))" -ForegroundColor Green
    Write-Host "Cancelling subscription $($Subscription.name)" -ForegroundColor Green
    Write-Host "--------------------------------" -ForegroundColor Green
    SubscriptionRBACCleanUp -Subscription $Subscription
      
    # Disable Azure subscription
    try {
      # Disable-AzSubscription -Id $Subscription.subscriptionId -Confirm:$false
      Write-Host "`u{2713} Subscription $($Subscription.name) disabled. You have 90days to recover Disabled subscriptions." -ForegroundColor Green
    }
    catch {
      Write-Host "Error disabling subscription :$($Subscription.name)`n Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Move the subscription to the cancelled management group
    try {
      New-AzManagementGroupSubscription -GroupId $CancelledManagementGroupId -SubscriptionId $Subscription.subscriptionId | Out-Null
      Write-Host "`u{2713} Subscription $($Subscription.name) moved to $CancelledManagementGroupId management group" -ForegroundColor Green
    }
    catch {
      Write-Host "Error moving subscription :$($Subscription.name) to management group $CancelledManagementGroupId `n Error: $($_.Exception.Message)" -ForegroundColor Red
    }
  }
  else {
    $remainingDays = (New-TimeSpan -Start (Get-Date) -End $expiryDate).Days
    if ($remainingDays -gt 0) {
      if ($remainingDays -le $AlarmPeriod) {
        Write-Host "Subscription $($Subscription.name) is reaching expiry date. Remaining days to expiry: $remainingDays" -ForegroundColor Yellow
      } else {
        Write-Host "Subscription $($Subscription.name) is valid. Remaining days to expiry: $remainingDays" -ForegroundColor Green
      }
      # TO DO ALARM Function
    } else {
      Write-Host "Subscription $($Subscription.name) has reached expiration date, observing grace period. Remaining days: $($remainingDays+$GracePeriod)" -ForegroundColor Yellow
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
    Write-Host "`u{2713} Subscription $($Subscription.name) has no role assignments." -ForegroundColor Green
  }
}

# Removes privileged role assignments
function RBACRemoval() {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]$roleAssignments
  )
  write-host "Removing Privileged RBAC assignments" -ForegroundColor Green
  foreach ($roleAssignment in $roleAssignments) {
    if ($roleAssignment.RoleDefinitionName -in $privilegedroles) {
      if ($roleAssignment.DisplayName -notin $excludedPrincipals) {
        try {
          Get-AzRoleAssignment -ObjectId $roleAssignment.ObjectId -RoleDefinitionId $roleAssignment.RoleDefinitionId | Remove-AzRoleAssignment 
        }
        catch {
          Write-Host "Error removing role assignment $($roleAssignment.DisplayName)`n($_.Exception.Message)" -ForegroundColor Red
          continue
        }
      }
    }
  }
  Write-Host "`u{2713} Privileged RBAC assignments removed" -ForegroundColor Green 
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
    Write-Host "Error getting expiry tag from subscription $($sub.name)" -ForegroundColor Red
    continue
  }

  if ($expiryDate) {
    try {
      SubscriptionExpiryAssessment -Subscription $sub -expiryDate $expiryDate
    }
    catch {
      Write-Host "Error Performing clean up activities on subscription:$($sub.name) `n Error: $($_.Exception.Message)" -ForegroundColor Red
      continue
    }
  }
}