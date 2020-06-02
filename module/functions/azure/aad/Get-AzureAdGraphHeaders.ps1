# <copyright file="Get-AzureAdGraphHeaders.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Populates the HTTP headers required to authenticate to the AzureAD Graph REST API.

.DESCRIPTION
Uses the AzureAD graph token from the current PowerShell Az context to populate the required HTTP authentication headers for use with the AzureAD Graph REST API.

.PARAMETER App
The AzureAD application object.

.OUTPUTS
Hashtable containing the required HTTP headers.
#>
function Get-AzureAdGraphHeaders
{
    [CmdletBinding()]
    param
    (
    )
    
    if (Test-AzureGraphAccess) {
        $graphToken = Get-AzureAdGraphToken
        $authToken = $graphToken.AccessToken
        $authHeaderValue = "Bearer $authToken"
        return @{"Authorization" = $authHeaderValue; "Content-Type"="application/json"}
    }
    else {
        Write-Error "No graph token available"
    }
}