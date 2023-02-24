# <copyright file="Set-TemporaryAzureResourceNetworkAccess.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
tbc

.DESCRIPTION
tbc

.PARAMETER ResourceType
tbc

.PARAMETER ResourceGroupName
tbc

.PARAMETER ResourceName
tbc

.PARAMETER Revoke
When true, any existing temporary network access rules for the specified resource will be removed.

#>
function Set-TemporaryAzureResourceNetworkAccess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("SqlServer","StorageAccount","WebApp")]
        [string] $ResourceType,

        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $ResourceName,

        [switch] $Revoke
    )

    $ruleName = "Temporary rule added by 'Enable-TemporaryAzureResourceAccess'"

    $currentPublicIpAddress = (Invoke-RestMethod https://ifconfig.io).Trim()
    Write-Host "currentPublicIpAddress: $currentPublicIpAddress"

    switch ($ResourceType) {

        "WebApp" {
            $removeExistingRules = {
                Get-AzWebApp -ResourceGroupName $ResourceGroupName `
                            -Name $ResourceName |
                    Select-Object -ExpandProperty SiteConfig |
                    Select-Object -ExpandProperty ScmIpSecurityRestrictions |
                    ? { $_.Name -eq $ruleName } |
                    % {
                        Remove-AzWebAppAccessRestrictionRule -ResourceGroupName $ResourceGroupName `
                                                             -WebAppName $ResourceName `
                                                             -TargetScmSite `
                                                             -IpAddress $_.IpAddress `
                                                             -Verbose
                    }
            }

            $addRule = {
                Add-AzWebAppAccessRestrictionRule `
                    -ResourceGroupName $ResourceGroupName `
                    -WebAppName $ResourceName `
                    -TargetScmSite `
                    -Name $ruleName `
                    -IpAddress "$currentPublicIpAddress/32" `
                    -Priority 100 `
                    -Action Allow
            }


        }

        "SqlServer" {
            $removeExistingRules = {
                Get-AzSqlServerFirewallRule -ResourceGroupName $ResourceGroupName `
                                            -ServerName $ResourceName |
                    ? { $_.FirewallRuleName -eq $ruleName } |
                    Remove-AzSqlServerFirewallRule -Verbose
            }

            $addRule = {
                New-AzSqlServerFirewallRule `
                    -ResourceGroupName $ResourceGroupName `
                    -ServerName $ResourceName `
                    -StartIpAddress $currentPublicIpAddress `
                    -EndIpAddress $currentPublicIpAddress `
                    -FirewallRuleName $ruleName
            }
        }

        "StorageAccount" {
            $removeExistingRules = {}
            $addRule = {}
        }
    }

    $logSuffix = "[ResourceType=$ResourceType][ResourceGroupName=$ResourceGroupName][ResourceName=$ResourceName]"

    Write-Host "Purging existing temporary network access rules $logSuffix"
    $removeExistingRules.Invoke() | Out-Null
    
    if (!$Revoke) {
        Write-Host "Granting temporary network access to '$currentPublicIpAddress' $logSuffix"
        $addRule.Invoke() | Out-Null
    }
}