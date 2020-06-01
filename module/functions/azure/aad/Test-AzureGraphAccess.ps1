# <copyright file="Test-AzureGraphAccess.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Tests whether the current PowerShell Az context has access to the AzureAD Graph API.

.DESCRIPTION
Performs a dummy operation against the AzureAD Graph API to force the issuance of an access token, if permitted.

.OUTPUTS
True when an AzureAD Graph API access token is available, otherwise False.
#>
function Test-AzureGraphAccess
{
    [CmdletBinding()]
    param
    (
    )

    # perform an arbitrary AAD operation to force getting a graph api token, in case don't yet have one
    Get-AzADApplication -ApplicationId (New-Guid).Guid -ErrorAction SilentlyContinue | Out-Null
  
    if ( !(Get-AzureAdGraphToken) ) {
        return $False
    }
    else {
        return $True
    }
}