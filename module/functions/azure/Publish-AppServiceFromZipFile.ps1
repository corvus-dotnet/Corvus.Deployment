# <copyright file="Publish-AppServiceFromZipFile.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Performs a .ZIP file deployment to an existing Azure Web App.

.DESCRIPTION
Verifies that the Azure Web App is available and then publishes the locally-available .ZIP file to it.

.OUTPUTS
Microsoft.Azure.Commands.WebApps.Models.PSSite
#>
function Publish-AppServiceFromZipFile
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$AppServiceName
    )

    $WebApp = Get-AzWebApp -Name $AppServiceName
    if (-not $WebApp) {
        Write-Error "Could not find the web app '$AppServiceName' - has it been provisioned yet?"
    }

    if ( !(Test-Path $Path) ) {
        Write-Error "Could not find application package: $Path"
    }

    Write-Host "Deploying application ZIP file '$Path' to '$AppServiceName'..."
    $publishResult = Publish-AzWebApp -Force -ArchivePath $Path -WebApp $WebApp

    return $publishResult
}