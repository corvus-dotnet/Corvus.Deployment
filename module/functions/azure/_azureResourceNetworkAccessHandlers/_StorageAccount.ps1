# <copyright file="_StorageAccount.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Set-StrictMode -Version Latest

function _removeExistingTempRules_StorageAccount {
    <#
    .SYNOPSIS
    Implements the handler for removing temporary network access rule(s) for Azure Storage Account.

    .DESCRIPTION
    Implements the handler for removing temporary network access rule(s) for Azure Storage Account.

    .PARAMETER ResourceGroupName
    The resource group of the Storage Account instance being updated.

    .PARAMETER ResourceName
    The name of the Storage Account instance being updated.

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

    $currentRules = Get-AzStorageAccountNetworkRuleSet `
                        -ResourceGroupName $ResourceGroupName `
                        -Name $ResourceName

    # Storage account network rules do not support comments so we can only filter by our current IP address
    $updatedRules = $currentRules.IpRules |
                        Where-Object { $_.IPAddressOrRange -ne $script:currentPublicIpAddress }

    Update-AzStorageAccountNetworkRuleSet `
        -ResourceGroupName $ResourceGroupName `
        -Name $ResourceName `
        -IPRule $updatedRules
}

function _addTempRule_StorageAccount {
    <#
    .SYNOPSIS
    Implements the handler for adding temporary network access rule for Azure Storage Account.

    .DESCRIPTION
    Implements the handler for adding temporary network access rule for Azure Storage Account.

    .PARAMETER ResourceGroupName
    The resource group of the Storage Account instance being updated.

    .PARAMETER ResourceName
    The name of the Storage Account instance being updated.

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

    $currentRules = Get-AzStorageAccountNetworkRuleSet `
                        -ResourceGroupName $ResourceGroupName `
                        -Name $ResourceName

    Update-AzStorageAccountNetworkRuleSet `
        -ResourceGroupName $ResourceGroupName `
        -Name $ResourceName `
        -IPRule ($currentRules.IpRules + @{
            IPAddressOrRange = $script:currentPublicIpAddress
            Action = "allow"
        })
}

function _waitForRule_StorageAccount {
    <#
    .SYNOPSIS
    Implements the typical delay required before network access rules take effect for this resource type.

    .DESCRIPTION
    Implements the typical delay required before network access rules take effect for this resource type.
    #>

    [CmdletBinding()]
    param ()
    
    Write-Host "Waiting 30 seconds to allow rule changes to take effect..."
    Start-Sleep -Seconds 30
}