# <copyright file="Get-MicrosoftGraphApiAppUri.ps1" company="Endjin Limited">
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
The Microsoft Graph REST API request URI as a string.
#>
function Get-MicrosoftGraphApiAppUri
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphApplication] $App
    )

    $graphApiAppUri = ("https://graph.microsoft.com/v1.0/{0}/applications/{1}" -f $script:moduleContext.AadTenantId, $App.Id)

    return $graphApiAppUri
}