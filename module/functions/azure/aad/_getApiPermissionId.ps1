# <copyright file="_getApiPermissionId.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Provides a convenient lookup for API permission identifiers using their names.

.DESCRIPTION
Provides a convenient lookup for API permission identifiers using their names. Uses the Azure Application definition
of the API to create an in-memory cache of mappings from permission name to guid-based ID.

.PARAMETER ApiName
The 'friendly' name of the API as defined used by the internal mapping

.PARAMETER Permission
The display name of the API permission to be assigned.

.PARAMETER Type
The type of permission assignment required, supported values are 'Application' or 'Delegated'.

.NOTES
The supported API names are as follows:
@{
    "AzureGraph" = "00000002-0000-0000-c000-000000000000"
    "MSGraph"    = "00000003-0000-0000-c000-000000000000"
}
#>

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