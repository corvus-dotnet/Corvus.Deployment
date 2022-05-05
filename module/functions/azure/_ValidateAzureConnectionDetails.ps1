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
        [AllowEmptyString()]
        [string] $SubscriptionId,

        [Parameter(Mandatory=$true)]
        [string] $AadTenantId,

        [Parameter()]
        [switch] $AzPowerShell,

        [Parameter()]
        [switch] $AzureCli,

        [Parameter()]
        [switch] $TenantOnly
    )

    # NOTE: This function is exempt from the test requiring consumers of AzPowerShell to call _EnsureAzureConnection
    
    if ($AzPowerShell) {
        # Ensure PowerShell Az is connected with the details that have been provided
        $azContext = Get-AzContext
        if ( ($TenantOnly -or $azContext.Subscription.Id -eq $SubscriptionId) -and `
                $azContext.Tenant.Id -eq $AadTenantId
        ) {
            return $true
        }
        else {
            Write-Warning "AzPowerShell connection failed validation"
            if (!$TenantOnly) {
                Write-Warning "SubscriptionId: Specified [$SubscriptionId], Actual [$($azContext.Subscription.Id)]"
            }
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

        if ( ($TenantOnly -or $currentAccount.id -eq $SubscriptionId) -and `
                $currentAccount.tenantId -eq $AadTenantId
        ) {
            return $true
        }
        else {
            Write-Warning "AzureCli connection failed validation"
            if (!$TenantOnly) {
                Write-Warning "SubscriptionId: Specified [$SubscriptionId], Actual [$($currentAccount.id)]"
            }
            Write-Warning "TenantId      : Specified [$AadTenantId], Actual [$($currentAccount.tenantId)]"
            return $false
        }
    }
}