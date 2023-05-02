# <copyright file="Assert-AzureAdAppRole.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an AzureAD application role with the specified configuration exists.

.DESCRIPTION
Ensures that an AzureAD application role with the specified configuration exists, creating or updating as necessary.

.PARAMETER AppObjectId
The object ID of the AzureAD application of which to add the role to.

.PARAMETER AppRoleId
Used to search for an existing AzureAD application role or create one with the specified name.

.PARAMETER DisplayName
The display name for the application role.

.PARAMETER Description
The description for the application role.

.PARAMETER Value
The value for the application role.

.PARAMETER AllowedMemberTypes
Allowed member types for the application (User / Application)

.OUTPUTS
Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphApplication
#>
function Assert-AzureAdAppRole
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true)]
        [string] $AppObjectId,

        [Parameter(Mandatory=$true)]
        [string] $AppRoleId,

        [Parameter(Mandatory=$true)]
        [string] $DisplayName,

        [Parameter(Mandatory=$true)]
        [string] $Description,

        [Parameter(Mandatory=$true)]
        [string] $Value,
        
        [Parameter(Mandatory=$true)]
        [string[]] $AllowedMemberTypes,

        [bool] $Enabled = $true
    )
    
    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null

    $app = Get-AzADApplication -Id $AppObjectId

    $AppRole = $app.AppRoles | Where-Object { $_.id -eq $AppRoleId }

    if ($AppRole) {
        Write-Host "Updating '$Value' app role"

        $AppRole.displayName = $DisplayName
        $AppRole.isEnabled = $Enabled
        $AppRole.description = $Description
        $AppRole.value = $Value
        $AppRole.allowedMemberTypes = $AllowedMemberTypes
    }
    else {
        Write-Host "Adding '$Value' app role"

        $AppRole = @{
            displayName = $DisplayName
            id = $AppRoleId
            isEnabled = $Enabled
            description = $Description
            value = $Value
            allowedMemberTypes = $AllowedMemberTypes
        }
        $app.AppRoles += $AppRole
    }

    Update-AzADApplication -ObjectId $AppObjectId -AppRole $app.AppRoles

    $app = Get-AzADApplication -Id $AppObjectId

    return $app
}
