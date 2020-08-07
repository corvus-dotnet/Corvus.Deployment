# <copyright file="Get-AzureAdGraphApiAppUri.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Derives URI needed to retrieve the specified AzureAD application from the AzureAD Graph REST API.

.DESCRIPTION
Derives URI needed to retrieve the specified AzureAD application from the AzureAD Graph REST API.

.PARAMETER App
The AzureAD application object.

.OUTPUTS
The AzureAD Graph REST API request URI as a string.
#>
function Get-AzureAdGraphApiAppUri
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ActiveDirectory.PSADApplication] $App
    )

    $graphApiAppUri = ("https://graph.windows.net/{0}/applications/{1}?api-version=1.6" -f $script:AadTenantId, $App.ObjectId)

    return $graphApiAppUri
}