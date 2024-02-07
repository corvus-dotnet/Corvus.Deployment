# <copyright file="_KeyVault.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _removeExistingTempRules_KeyVault {
    <#
    .SYNOPSIS
    Implements the handler for removing temporary network access rule(s) for Azure Key Vault.

    .DESCRIPTION
    Implements the handler for removing temporary network access rule(s) for Azure Key Vault.

    .PARAMETER ResourceGroupName
    The resource group of the Key Vault instance being updated.

    .PARAMETER ResourceName
    The name of the Key Vault instance being updated.

    .NOTES
    Handlers expect the following script-level variables to have been defined by their caller, which of them are
    consumed by a given handler is implementation-specific.

        - $script:currentPublicIpAddress
        - $script:ruleName
        - $script:ruleDescription
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $ResourceName
    )

    _EnsureAzureConnection -AzPowerShell

    $currentAllowedIPs = Get-AzKeyVault `
                        -ResourceGroupName $ResourceGroupName `
                        -VaultName $ResourceName |
        Select-Object -ExpandProperty NetworkAcls |
        Select-Object -ExpandProperty IpAddressRanges 

    # Key Vault stores IP addresses with a '/32' suffix even when it wasn't specified when adding the rule (unlike Storage Accounts)
    $currentPublicIpAddressForKv = "{0}/32" -f $script:currentPublicIpAddress

    # Key vault network rules do not support comments so we can only filter by our current IP address
    $updatedAllowedIPs = $currentAllowedIPs | Where-Object { $_ -ne $currentPublicIpAddressForKv }

    Update-AzKeyVaultNetworkRuleSet `
        -ResourceGroupName $ResourceGroupName `
        -VaultName $ResourceName `
        -IpAddressRange $updatedAllowedIPs
}

function _addTempRule_KeyVault {
    <#
    .SYNOPSIS
    Implements the handler for adding temporary network access rule for Azure Key Vault.

    .DESCRIPTION
    Implements the handler for adding temporary network access rule for Azure Key Vault.

    .PARAMETER ResourceGroupName
    The resource group of the Key Vault instance being updated.

    .PARAMETER ResourceName
    The name of the Key Vault instance being updated.

    .NOTES
    Handlers expect the following script-level variables to have been defined by their caller, which of them are
    consumed by a given handler is implementation-specific.

        - $script:currentPublicIpAddress
        - $script:ruleName
        - $script:ruleDescription
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $ResourceName
    )

    _EnsureAzureConnection -AzPowerShell

    $currentAllowedIPs = Get-AzKeyVault `
                        -ResourceGroupName $ResourceGroupName `
                        -VaultName $ResourceName |
        Select-Object -ExpandProperty NetworkAcls |
        Select-Object -ExpandProperty IpAddressRanges 

    Update-AzKeyVaultNetworkRuleSet `
        -ResourceGroupName $ResourceGroupName `
        -VaultName $ResourceName `
        -IpAddressRange (([array]$currentAllowedIPs) + $script:currentPublicIpAddress)
}

function _waitForRule_KeyVault {
    <#
    .SYNOPSIS
    Implements the typical delay required before network access rules take effect for this resource type.

    .DESCRIPTION
    Implements the typical delay required before network access rules take effect for this resource type.
    #>

    [CmdletBinding()]
    param ()
    
    Write-Host "Waiting 10 seconds to allow rule changes to take effect..."
    Start-Sleep -Seconds 10
}