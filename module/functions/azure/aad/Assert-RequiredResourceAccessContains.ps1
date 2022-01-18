# <copyright file="Assert-RequiredResourceAccessContains.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an existing AzureAD application has the required ResourceAccess specified in its manifest.

.DESCRIPTION
Ensures that an existing AzureAD application has the required ResourceAccess specified in its manifest.

.PARAMETER App
The AzureAD application object.

.PARAMETER ResourceId
The ID of the resource to which the access is required.

.PARAMETER AccessRequirements
The access required to the specified resource.

.OUTPUTS
The AzureAD application's manifest returned by the Azure Graph REST API.
#>
function Assert-RequiredResourceAccessContains
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ActiveDirectory.PSADApplication] $App,

        [Parameter(Mandatory=$true)]
        [string] $ResourceId,

        [Parameter(Mandatory=$true)]
        [hashtable[]] $AccessRequirements,

        [Parameter()]
        [switch] $UseAzureAdGraph
    )

    $madeChange = $false
    [array]$requiredResourceAccess = (Get-AzureADApplicationManifest $App).requiredResourceAccess
    $resourceEntry = $requiredResourceAccess | Where-Object {$_.resourceAppId -eq $ResourceId }
    if (-not $resourceEntry) {
        $madeChange = $true
        $resourceEntry = @{resourceAppId=$ResourceId;resourceAccess=@()}
        $requiredResourceAccess += $resourceEntry
    }
    
    foreach ($access in $AccessRequirements) {
        $RequiredAccess = $resourceEntry.resourceAccess| Where-Object {$_.id -eq $access.Id -and $_.type -eq $access.Type}
        if (-not $RequiredAccess) {
            Write-Host "Adding '$ResourceId : $($access.id)' required resource access"
    
            $RequiredAccess = @{id=$access.Id; type=$access.Type}
            $resourceEntry.resourceAccess += $RequiredAccess
            $madeChange = $true
        }
    }

    if ($madeChange) {
        if ($UseAzureAdGraph) {
            $graphApiAppUri = (Get-AzureAdGraphApiAppUri $App)
        }
        else {
            $graphApiAppUri = (Get-MicrosoftGraphApiAppUri $App)
        }

        $patchRequiredResourceAccess = @{requiredResourceAccess=$requiredResourceAccess}

        $response = Invoke-AzCliRestCommand -Uri $graphApiAppUri `
                                            -Method 'PATCH' `
                                            -Body $patchRequiredResourceAccess

        $appManifest = Invoke-AzCliRestCommand -Uri $graphApiAppUri

        return $appManifest
    }
}