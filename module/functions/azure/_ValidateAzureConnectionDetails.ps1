# <copyright file="_ValidateAzureConnectionDetails.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Checks whether an existing Azure connection is still associated with originally intended Tenant and Subscription.

.DESCRIPTION
Checks whether an existing Azure connection is still associated with originally intended Tenant and Subscription.

#>
function _ValidateAzureConnectionDetails
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $SubscriptionId,

        [Parameter(Mandatory=$true)]
        [string] $AadTenantId,

        [Parameter()]
        [switch] $AzPowerShell,

        [Parameter()]
        [switch] $AzureCli
    )

    # NOTE: This function is exempt from the test requiring consumers of AzPowerShell to call _EnsureAzureConnection
    
    if ($AzPowerShell) {
        # Ensure PowerShell Az is connected with the details that have been provided
        $azContext = Get-AzContext
        if ($azContext.Subscription.Id -eq $SubscriptionId -and `
                $azContext.Tenant.Id -eq $AadTenantId
        ) {
            return $true
        }
        else {
            Write-Warning "SubscriptionId: Specified [$SubscriptionId], Actual [$($azContext.Subscription.Id)]"
            Write-Warning "TenantId      : Specified [$AadTenantId], Actual [$($azContext.Tenant.Id)]"
            return $false
        }
    }

    if ($AzureCli) {
        # Ensure AzureCLI is connected with the details that have been provided
        try {
            $currentAccount = Invoke-AzCli "account show" -asJson -SuppressConnectionValidation
        }
        catch {}

        if ($currentAccount.id -eq $SubscriptionId -and `
                $currentAccount.tenantId -eq $AadTenantId
        ) {
            return $true
        }
        else {
            Write-Warning "SubscriptionId: Specified [$SubscriptionId], Actual [$($currentAccount.id)]"
            Write-Warning "TenantId      : Specified [$AadTenantId], Actual [$($currentAccount.tenantId)]"
            return $false
        }
    }
}