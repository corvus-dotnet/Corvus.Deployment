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

.PARAMETER UseAzureAdGraph
By default, the Microsoft Graph will be used for the graph operations. If you enable this switch, the legacy Azure AD Graph will be used instead.

.OUTPUTS
Microsoft.Azure.Commands.ActiveDirectory.PSADApplication
#>
function Assert-AzureAdAppRole
{
    [CmdletBinding()]
    param 
    (
        [string] $AppObjectId,
        [string] $AppRoleId,
        [string] $DisplayName,
        [string] $Description,
        [string] $Value,
        [string[]] $AllowedMemberTypes,
        [switch] $UseAzureAdGraph
    )
    
    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null

    $TenantId = $script:moduleContext.AadTenantId

    $AppUriSegment = ("applications/{0}" -f $AppObjectId)

    $GraphApiAppUri = $UseAzureAdGraph ?
        "https://graph.windows.net/{0}/{1}?api-version=1.5" -f $TenantId, $AppUriSegment : 
        "https://graph.microsoft.com/v1.0/{0}" -f $AppUriSegment


    $App = Invoke-AzCliRestCommand -Uri $GraphApiAppUri

    $AppRoles = $App.appRoles

    $AppRole = $AppRoles | Where-Object { $_.id -eq $AppRoleId }

    if ($AppRole) {
        Write-Host "Updating $Value app role"

        $AppRole.isEnabled = $true
        $AppRole.description = $Description
        $AppRole.value = $Value
        $AppRole.allowedMemberTypes = $AllowedMemberTypes
    }
    else {
        Write-Host "Adding $Value app role"

        $AppRole = @{
            displayName = $DisplayName
            id = $AppRoleId
            isEnabled = $true
            description = $Description
            value = $Value
            allowedMemberTypes = $AllowedMemberTypes
        }
        $AppRoles += $AppRole
    }

    $UpdateResponse = Invoke-AzCliRestCommand `
        -Uri $GraphApiAppUri `
        -Method "PATCH" `
        -Body @{appRoles=$AppRoles}

    $App = Invoke-AzCliRestCommand -Uri $GraphApiAppUri

    return $App
    
}
