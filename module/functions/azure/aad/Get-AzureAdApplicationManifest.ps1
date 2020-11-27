# <copyright file="Get-AzureAdApplicationManifest.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Retrieves the AzureAD application manifest using the AzureAD Graph REST API.

.DESCRIPTION
Retrieves the AzureAD application manifest using the AzureAD Graph REST API.

.PARAMETER App
The AzureAD application object.

.OUTPUTS
The AzureAD application's manifest returned by the Azure Graph REST API.
#>
function Get-AzureADApplicationManifest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ActiveDirectory.PSADApplication] $App
    )

    $manifest = Invoke-AzCliRestCommand -Uri (Get-AzureAdGraphApiAppUri $App)

    return $manifest
}