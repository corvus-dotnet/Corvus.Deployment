# <copyright file="_WebAppScm.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>


function _removeExistingTempRules_WebAppScm {
    <#
    .SYNOPSIS
    Implements the handler for removing temporary network access rule(s) for the App Service SCM site.

    .DESCRIPTION
    Implements the handler for removing temporary network access rule(s) for the App Service SCM site.

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
        Select-Object -ExpandProperty ScmIpSecurityRestrictions |
        Where-Object { $_.Name -eq $script:ruleName } |
        ForEach-Object {
            Remove-AzWebAppAccessRestrictionRule -ResourceGroupName $ResourceGroupName `
                                                 -WebAppName $ResourceName `
                                                 -TargetScmSite `
                                                 -IpAddress $_.IpAddress `
                                                 -Verbose
        }
}

function _addTempRule_WebAppScm {
    <#
    .SYNOPSIS
    Implements the handler for adding a temporary network access rule for the App Service SCM site.

    .DESCRIPTION
    Implements the handler for adding temporary network access rule for the App Service SCM site.

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
        -TargetScmSite `
        -Name $script:ruleName `
        -Description $script:ruleDescription `
        -IpAddress "$($script:currentPublicIpAddress)/32" `
        -Priority 100 `
        -Action Allow
}