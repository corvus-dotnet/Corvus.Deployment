# <copyright file="_WebApp.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _removeExistingTempRules_WebApp {
    <#
    .SYNOPSIS
    Implements the handler for removing temporary network access rule(s) for the App Service main web site.

    .DESCRIPTION
    Implements the handler for removing temporary network access rule(s) for the App Service main web site.

    .PARAMETER ResourceGroupName
    The resource group of the App Service instance being updated.

    .PARAMETER ResourceName
    The name of the App Service instance being updated.

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

    Get-AzWebApp -ResourceGroupName $ResourceGroupName `
                 -Name $ResourceName |
        Select-Object -ExpandProperty SiteConfig |
        Select-Object -ExpandProperty IpSecurityRestrictions |
        Where-Object { $_.Name -eq $script:ruleName } |
        ForEach-Object {
            Remove-AzWebAppAccessRestrictionRule -ResourceGroupName $ResourceGroupName `
                                                 -WebAppName $ResourceName `
                                                 -IpAddress $_.IpAddress `
                                                 -Verbose
        }
}

function _addTempRule_WebApp {
    <#
    .SYNOPSIS
    Implements the handler for adding a temporary network access rule for the App Service main web site.

    .DESCRIPTION
    Implements the handler for adding temporary network access rule for the App Service main web site.

    .PARAMETER ResourceGroupName
    The resource group of the App Service instance being updated.

    .PARAMETER ResourceName
    The name of the App Service instance being updated.

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

    Add-AzWebAppAccessRestrictionRule `
        -ResourceGroupName $ResourceGroupName `
        -WebAppName $ResourceName `
        -Name $script:ruleName `
        -Description $script:ruleDescription `
        -IpAddress "$($script:currentPublicIpAddress)/32" `
        -Priority 100 `
        -Action Allow
}

function _waitForRule_WebApp {
    <#
    .SYNOPSIS
    Implements the typical delay required before network access rules take effect for this resource type.

    .DESCRIPTION
    Implements the typical delay required before network access rules take effect for this resource type.
    #>

    [CmdletBinding()]
    param ()

    Write-Host "Waiting 5 seconds to allow rule changes to take effect..."
    Start-Sleep -Seconds 5
}