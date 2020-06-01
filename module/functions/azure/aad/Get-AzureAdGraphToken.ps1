# <copyright file="Get-AzureAdGraphToken.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Returns the AzureAD Graph API access token from the current PowerShell Az context, if available.

.DESCRIPTION
Returns the AzureAD Graph API access token from the current PowerShell Az context, if available.

.OUTPUTS
A string containing the access token, or $null if one is not available.
#>
function Get-AzureAdGraphToken
{
    [CmdletBinding()]
    param
    (
    )
    
    $graphToken = $script:AzContext.TokenCache.ReadItems() | Where-Object {
        # service principals with a graph tokens appear unassociated with a tenant, whilst users are
        (!($_.TenantId) -or $_.TenantId -eq $script:AadTenantId) -and $_.Resource -eq $script:AadGraphApiResourceId
    }

    return $GraphToken
}