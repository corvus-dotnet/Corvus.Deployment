# <copyright file="Connect-Azure.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Authenticates the current session to Azure via both Az PowerShell and the AzureCLI.

.DESCRIPTION
To help safeguard against running automation scripts against the incorrect Azure Tenant or Subscription
this module requires an explicit connection to be setup.

This function uses the provided details to ensure an authenticated session for both the
Az PowerShell Cmdlets and the AzureCLI exists for the specified Tenant/Subscription.

The function attempts to detect when running interactively to enable a manual login if not already
authenticated.

NOTE: It is intended that other functions within this module that use either of these 2 tools must validate
that a connection has been setup.

.PARAMETER SubscriptionId
The Azure Subscription that is the default target for any Azure operations.

.PARAMETER AadTenantId
The Azure Tenant that the Subscription belongs to.

.PARAMETER SkipAzPowerShell
When true, a connection to Azure via the Az PowerShell cmdlets will not be initialised.

.PARAMETER SkipAzureCli
When true, a connection to Azure via the AzureCLI will not be initialised.

#>

function Connect-Azure
{
    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
        [Parameter(ParameterSetName="Default", Mandatory=$true)]
        [guid] $SubscriptionId,

        [Parameter(Mandatory=$true)]
        [guid] $AadTenantId,

        [switch] $SkipAzPowerShell,
        [switch] $SkipAzureCli,

        [Parameter(ParameterSetName="NoSubscriptions")]
        [switch] $TenantOnly
    )
    
    # NOTE: This function is exempt from the test requiring consumers of AzPowerShell to call _EnsureAzureConnection

    $script:moduleContext.TenantOnly = $TenantOnly
    $script:moduleContext.SubscriptionId = $script:moduleContext.NoSubscriptions ? "" : $SubscriptionId
    $script:moduleContext.AadTenantId = $AadTenantId

    if ($script:moduleContext.TenantOnly) {
        Write-Host "Connecting with 'TenantOnly' option"
    }

    # Attempt to detect if we're running interactively
    $isInteractive = [Environment]::UserInteractive -and !(Test-Path env:\SYSTEM_TEAMFOUNDATIONSERVERURI)

    if (-not $SkipAzPowerShell) {
        Write-Host "Validating Az PowerShell connection"
        
        $ctx = Get-AzContext
        if (!$ctx -and $isInteractive) {
            Write-Host "Not currently logged-in to Az PowerShell - triggering manual login"
            $connectSplat = @{
                TenantId = $AadTenantId
            }
            if (!$TenantOnly) {
                $connectSplat += @{
                    SubscriptionId = $SubscriptionId
                }
            }
            Connect-AzAccount @connectSplat | Out-Null
        }
        elseif ($ctx -and `
                    $ctx.Tenant.Id -eq $AadTenantId -and `
                    (!$TenantOnly -and $ctx.Subscription.Id -ne $script:moduleContext.SubscriptionId)
        ) {
            # Try to switch to the required subscription, if we are connected to the right tenant.
            # This avoids an unnecessary validation failure when we're connected to the right tenant,
            # but not the intended subscription
            Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
        }

        if (!(_ValidateAzureConnectionDetails -SubscriptionId $script:moduleContext.SubscriptionId -AadTenantId $AadTenantId -AzPowerShell -TenantOnly:$TenantOnly)) {
            Write-Error "The current Az PowerShell connection context does not match the specified details"
        }
        else {
            $script:moduleContext.AzPowerShell.Connected = $true
        }
    }

    if (-not $SkipAzureCli) {
        Write-Host "Validating AzureCLI connection"
        $splat = @{
            AadTenantId = $AadTenantId
        }
        if ($TenantOnly) {
            $splat += @{ TenantOnly = $TenantOnly }
        }
        else {
            $splat += @{ SubscriptionId = $script:moduleContext.SubscriptionId }
        }
        Assert-AzCliLogin @splat | Out-Null
        
        if (!(_ValidateAzureConnectionDetails -SubscriptionId $script:moduleContext.SubscriptionId -AadTenantId $AadTenantId -AzureCli -TenantOnly:$TenantOnly)) {
            Write-Error "The current AzureCLI connection context does not match the specified details."
        }
        else {
            $script:moduleContext.AzureCli.Connected = $true
        }
    }
}