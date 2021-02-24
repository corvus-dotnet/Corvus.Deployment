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

    function _getApiId
    {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            [ValidateSet("AzureGraph","MSGraph")]
            [string] $ApiName
        )

        $apiLookup = @{
            "AzureGraph" = "00000002-0000-0000-c000-000000000000"
            "MSGraph" = "00000003-0000-0000-c000-000000000000"
        }
        
        return $apiLookup[$ApiName]
    }

    function _getApiPermissionId
    {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            [ValidateSet("AzureGraph","MSGraph")]
            [string] $ApiName,
    
            [Parameter(Mandatory=$true)]
            [string] $Permission,

            [Parameter(Mandatory=$true)]
            [ValidateSet("Application","Delegated")]
            [string] $Type
        )

        $apiId = _getApiId -ApiName $ApiName

        if (!(Get-Variable "apiPermissionsList" -Scope Global -EA 0)) {
            $global:apiPermissionsList = @{}
        }

        if (!($global:apiPermissionsList.ContainsKey($apiId))) {
            $cmd = @(
                "ad sp show"
                "--id $apiId"
            )
            $apiApp = Invoke-AzCli $cmd -AsJson
            $global:apiPermissionsList += @{ "$apiId" = $apiApp }
        }

        switch($Type)
        {
            "Application" { $queryMember = "appRoles" }
            "Delegated" { $queryMember = "oauth2Permissions" }
        }

        $permissionEntry = $global:apiPermissionsList[$apiId].$queryMember | `
                                Where-Object { $_.value -eq $Permission }

        if (!$permissionEntry) {
            throw "The $ApiName permission '$Permission' of type '$Type' could not be found - check the name and type details"
        }

        return $permissionEntry.id
    }

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