# <copyright file="Assert-AzureAdApp.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an AzureAD application with the specified configuration exists.

.DESCRIPTION
Ensures that an AzureAD application with the specified configuration exists, creating or updating as necessary.

.PARAMETER DisplayName
Used to search for an existing AzureAD application or create one with the specified name.

.PARAMETER AppUri
The URL to the application homepage.

.PARAMETER ReplyUrls
The application reply urls.

.OUTPUTS
Microsoft.Azure.Commands.ActiveDirectory.PSADApplication
#>
function Assert-AzureAdApp
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $DisplayName,

        [Parameter(Mandatory=$true)]
        [string] $AppUri,
        
        [string[]]$ReplyUrls
    )

    # Check whether we have a valid AzPowerShell connection
    _EnsureAzureConnection -AzPowerShell -ErrorAction Stop
    
    Write-Host "Ensuring Azure AD application {$DisplayName} exists..."

    $app = Get-AzADApplication -DisplayNameStartWith $DisplayName | `
                Where-Object {$_.DisplayName -eq $DisplayName}
    
    if ($app) {
        Write-Host "Found existing app with id $($app.ApplicationId)"
        $ReplyUrlsOk = $true
        ForEach ($ReplyUrl in $ReplyUrls) {
            if (-not $app.ReplyUrls.Contains($ReplyUrl)) {
                $ReplyUrlsOk = $false
                Write-Host "Reply URL $ReplyUrl not present in app"
            }
        }

        if (-not $ReplyUrlsOk) {
            Write-Host "Setting reply URLs: $replyUrls"
            $app = Update-AzADApplication -ObjectId $app.ObjectId `
                                          -ReplyUrl $ReplyUrls
        }
    } else {
        $app = New-AzADApplication -DisplayName $DisplayName `
                                   -IdentifierUris $AppUri `
                                   -HomePage $AppUri `
                                   -ReplyUrls $ReplyUrls
        Write-Host "Created new app with id $($app.ApplicationId)"
    }

    return $app
}
