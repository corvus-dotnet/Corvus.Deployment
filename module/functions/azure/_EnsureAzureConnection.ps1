# <copyright file="_EnsureAzureConnection.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Checks whether a valid Azure connection is available, as setup using 'Connect-Azure'.

.DESCRIPTION
Also validates that the existing connection is still associated with originally intended Tenant and Subscription.

#>

function _EnsureAzureConnection
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch] $AzPowerShell,

        [Parameter()]
        [switch] $AzureCli
    )

    function _validateAzPowerShell
    {
        $valid = (
            $script:moduleContext.AzPowerShell.Connected -and `
            (_ValidateAzureConnectionDetails -SubscriptionId $script:moduleContext.SubscriptionId -AadTenantId $script:moduleContext.AadTenantId -AzPowerShell)
        )
        return $valid

    }
    function _validateAzureCli
    {
        $valid = (
            $script:moduleContext.AzureCli.Connected -and `
            (_ValidateAzureConnectionDetails -SubscriptionId $script:moduleContext.SubscriptionId -AadTenantId $script:moduleContext.AadTenantId -AzureCli)
        )
        return $valid
    }

    if (!$AzPowerShell -and !$AzureCli) {
        # If no switches are specified, assume both need to be checked
        $AzPowerShell = $AzureCli = $true
    }

    $isValid = $false

    if ($AzPowerShell -and $AzureCli) {
        $isValid =  _validateAzPowerShell -and _validateAzureCli
    }
    elseif ($AzPowerShell) {
        $isValid = _validateAzPowerShell
    }
    elseif ($AzureCli) {
        $isValid = _validateAzureCli
    }

    if (!$isValid) {
        throw "A valid Azure connection was not found - have you run 'Connect-CorvusAzure'?"
    }

    return $isValid
}