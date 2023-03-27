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

.PARAMETER ResourceAppId
The Application ID of the resource to which the access is required.

.PARAMETER AccessRequirements
The access required to the specified resource.

.OUTPUTS
The Azure AD application object.
#>
function Assert-RequiredResourceAccessContains
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphApplication] $App,

        [Parameter(Mandatory=$true)]
        [Alias("ResourceId")]
        [string] $ResourceAppId,

        [Parameter(Mandatory=$true)]
        [hashtable[]] $AccessRequirements
    )

    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null

    $madeChange = $false
    [array]$requiredResourceAccess = $App.requiredResourceAccess
    $resourceEntry = $requiredResourceAccess | Where-Object { $_.resourceAppId -eq $ResourceAppId }
    if (-not $resourceEntry) {
        $madeChange = $true
        $resourceEntry = @{
            resourceAppId = $ResourceAppId
            resourceAccess = @()
        }
        $requiredResourceAccess += $resourceEntry
    }
    
    foreach ($access in $AccessRequirements) {
        $requiredAccess = $resourceEntry.resourceAccess |
                            Where-Object { $_.id -eq $access.Id -and $_.type -eq $access.Type }
        if (-not $requiredAccess) {
            Write-Host "Adding '$ResourceAppId : $($access.id)' required resource access"
    
            $requiredAccess = @{
                id = $access.Id
                type=$access.Type
            }
            $resourceEntry.resourceAccess += $requiredAccess
            $madeChange = $true
        }
    }

    if ($madeChange) {
        $uri = $App | Get-MicrosoftGraphApiAppUri
        $body = @{
            requiredResourceAccess = $requiredResourceAccess
        }
        $resp = Invoke-AzRestMethod `
                    -Uri $uri `
                    -Method PATCH `
                    -Payload ($body | ConvertTo-Json -Depth 100 -Compress)
        if ($resp.StatusCode -ge 400) {
            throw $resp.Content
        }
        
        $App = Get-AzADApplication -ObjectId $App.Id

        return $App
    }
}