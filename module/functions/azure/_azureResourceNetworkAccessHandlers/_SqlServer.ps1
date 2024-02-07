# <copyright file="_SqlServer.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

Set-StrictMode -Version Latest

function _removeExistingTempRules_SqlServer {
    <#
    .SYNOPSIS
    Implements the handler for removing temporary network access rule(s) for Azure SQL Server.

    .DESCRIPTION
    Implements the handler for removing temporary network access rule(s) for Azure SQL Server.

    .PARAMETER ResourceGroupName
    The resource group of the SQL Server instance being updated.

    .PARAMETER ResourceName
    The name of the SQL Server instance being updated.

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

    Get-AzSqlServerFirewallRule -ResourceGroupName $ResourceGroupName `
                                -ServerName $ResourceName |
        Where-Object { $_.FirewallRuleName -eq $script:ruleName } |
        Remove-AzSqlServerFirewallRule -Verbose
}

function _addTempRule_SqlServer {
    <#
    .SYNOPSIS
    Implements the handler for adding temporary network access rule for Azure SQL Server.

    .DESCRIPTION
    Implements the handler for adding temporary network access rule for Azure SQL Server.

    .PARAMETER ResourceGroupName
    The resource group of the SQL Server instance being updated.

    .PARAMETER ResourceName
    The name of the SQL Server instance being updated.

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

    New-AzSqlServerFirewallRule `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ResourceName `
        -StartIpAddress $script:currentPublicIpAddress `
        -EndIpAddress $script:currentPublicIpAddress `
        -FirewallRuleName $script:ruleName
}

function _waitForRule_SqlServer {
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