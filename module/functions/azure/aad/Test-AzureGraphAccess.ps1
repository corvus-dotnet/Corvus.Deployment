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

    # Check whether we have a valid AzPowerShell connection
    _EnsureAzureConnection -AzPowerShell -ErrorAction Stop
    
    # perform an arbitrary AAD operation to see if we have read access to the graph API
    try {
        Get-AzADApplication -ApplicationId (New-Guid).Guid -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Message -match "Insufficient privileges") {
            return $False
        }
        else {
            throw $_
        }
    }

    return $True
}