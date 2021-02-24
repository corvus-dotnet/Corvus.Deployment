# <copyright file="Assert-ResourceGroupWithRbac.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that a resource group exists and that the specified service principal has the specified access to it.

.DESCRIPTION
Ensures that a resource group exists and that the specified service principal has the specified ARM role
assigned at the resource group scope.

.PARAMETER Name
The name of the resource group.

.PARAMETER Location
The Azure location of the resource group.

.PARAMETER ServicePrincipalName
The display name of the Azure AD identity.

.PARAMETER RoleName
The name of the ARM role definition to be assigned.

.PARAMETER ResourceTags
The ARM tags that should be applied to the resource group.

.OUTPUTS
Returns a hashtable representing the JSON object describing the resource group.

#>
function Assert-ResourceGroupWithRbac
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $Location,

        [Parameter(Mandatory=$true)]
        [string] $ServicePrincipalName,

        [Parameter(Mandatory=$true)]
        [string] $RoleName,

        [Parameter()]
        [hashtable] $ResourceTags
    )

    _EnsureAzureConnection

    $existingRg = Get-AzResourceGroup -Location $Location | `
                            Where-Object { $_.ResourceGroupName -eq $Name }

    if (!$existingRg) {
        if ($PSCmdlet.ShouldProcess($Name, "Create Resource Group")) {
            $existingRg = New-AzResourceGroup -Name $Name -Location $Location -Tags $ResourceTags
        }        
    }

    if (!$existingRg -and -not $WhatIfPreference) {
        throw "Unexpected error - the resource group $Name in $Location could not be found"
    }
    elseif ($existingRg) {
        $existingRbac = Get-AzRoleAssignment -Scope $existingRg.ResourceId `
                                                -RoleDefinitionName $RoleName `
                                                -ServicePrincipalName $ServicePrincipalName
    }
    else {
        $existingRbac = $null
    }
    
    if (!$existingRbac) {
        if ($PSCmdlet.ShouldProcess($RoleName, "Assign Role")) {
            $assignment = New-AzRoleAssignment -Scope $existingRg.ResourceId `
                                                -RoleDefinitionName $RoleName `
                                                -ServicePrincipalName $ServicePrincipalName
        }
    }

    return $existingRg
}