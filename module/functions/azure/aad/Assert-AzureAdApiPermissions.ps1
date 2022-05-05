# <copyright file="Assert-AzureAdApiPermissions.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an AAD application has the specified API permissions.

.DESCRIPTION
Supports assigning API permissions (by name) to an AAD application - both 'Application' and 'Delegated' permissions.

NOTE: This function currently supports assigning permissions to the 'Microsoft Graph' and the now deprecated 'Azure Graph' APIs.

.PARAMETER ApiName
The name of the API - 'AzureGraph' or 'MSGraph'.

.PARAMETER ApplicationPermissions
The list of 'Application' (or 'AppRole') permissions to be assigned. (e.g. 'Application.ReadWrite.OwnedBy')

.PARAMETER DelegatedPermissions
The list of 'Application' (or 'OAuth') permissions to be assigned. (e.g. 'Application.Read.All')

.PARAMETER ApplicationId
The ApplicationID or ClientId of the AAD identity who requires the assignments.

#>

function Assert-AzureAdApiPermissions
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("AzureGraph","MSGraph")]
        [string] $ApiName,

        [Parameter()]
        [string[]] $ApplicationPermissions,

        [Parameter()]
        [string[]] $DelegatedPermissions,

        [Parameter(Mandatory=$true)]
        [guid] $ApplicationId
    )

    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null
    
    [hashtable[]] $accessRequirements = @()
    foreach ($permission in $ApplicationPermissions) {
        $permisssionId = _getApiPermissionId -ApiName $ApiName -Permission $permission -Type Application
        $accessRequirements += @{Id=$permisssionId; Type="Role"}
    }

    foreach ($permission in $DelegatedPermissions) {
        $permisssionId = _getApiPermissionId -ApiName $ApiName -Permission $permission -Type Delegated
        $accessRequirements += @{Id=$permisssionId; Type="Scope"}
    }

    $app = Get-AzADApplication -ApplicationId $ApplicationId
    if ($PSCmdlet.ShouldProcess($ApplicationId)) {
        $appManifest = Assert-RequiredResourceAccessContains `
                            -App $app `
                            -ResourceId (_getApiId -ApiName $ApiName) `
                            -AccessRequirements $accessRequirements
    }
}