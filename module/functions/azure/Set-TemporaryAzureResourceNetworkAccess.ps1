# <copyright file="Set-TemporaryAzureResourceNetworkAccess.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Manages the addition and removal of temporary network access rules for different Azure resource types.

.DESCRIPTION
Each resource type implements its own handler for performing the addition and removal operations.

.PARAMETER ResourceType
The type of Azure resource to be managed.

.PARAMETER ResourceGroupName
The resource group of the resource to be managed.

.PARAMETER ResourceName
The name of the resource to be managed.

.PARAMETER Revoke
When true, any existing temporary network access rules for the specified resource will be removed. No
rules will be added.

#>
function Set-TemporaryAzureResourceNetworkAccess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("SqlServer","StorageAccount","WebApp","WebAppScm")]
        [string] $ResourceType,

        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $ResourceName,

        [switch] $Revoke
    )

    # Set optional values used by some handler implmentations
    $script:ruleName = "temp-cicd-rule"
    $script:ruleDescription = "Temporary rule added by 'Enable-TemporaryAzureResourceAccess'"
    $script:currentPublicIpAddress = (Invoke-RestMethod https://ifconfig.io).Trim()
    Write-Host "currentPublicIpAddress: $currentPublicIpAddress"

    # Configure handler settings for the given resource type
    $removeHandlerName = "_removeExistingTempRules_$ResourceType"
    $addHandlerName = "_addTempRule_$ResourceType"
    $handlerSplat = @{
        ResourceGroupName = $ResourceGroupName
        ResourceName = $ResourceName
    }

    $logSuffix = "[ResourceType=$ResourceType][ResourceGroupName=$ResourceGroupName][ResourceName=$ResourceName]"

    Write-Host "Purging existing temporary network access rules $logSuffix"
    & $removeHandlerName @handlerSplat | Out-Null
    
    if (!$Revoke) {
        Write-Host "Granting temporary network access to '$currentPublicIpAddress' $logSuffix"
        & $addHandlerName @handlerSplat
    }
}