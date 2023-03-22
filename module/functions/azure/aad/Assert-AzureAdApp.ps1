# <copyright file="Assert-AzureAdApp.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an AzureAD application with the specified configuration exists.

.DESCRIPTION
Ensures that an AzureAD application with the specified configuration exists, creating or updating as necessary.

.PARAMETER DisplayName
Used to search for an existing AzureAD application or create one with the specified name. Can only be updated for an existing AzureAD application when also updating the 'ReplyUrls' property.

.PARAMETER IdentifierUri
The URL to the application homepage. Can only be updated for an existing AzureAD application when also updating the 'ReplyUrls' property.

.PARAMETER ReplyUrls
The application reply urls. Can be updated for an existing AzureAD application.

.OUTPUTS
Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphApplication
#>
function Assert-AzureAdApp
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $DisplayName,

        [Parameter()]
        [Alias("AppUri")]
        [string] $IdentifierUri,
        
        [Parameter()]
        [string[]] $ReplyUrls
    )

    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null
    
    Write-Host "Ensuring Azure AD application {$DisplayName} exists..."

    $app = Get-AzADApplication -DisplayNameStartWith $DisplayName | `
                Where-Object {$_.DisplayName -eq $DisplayName}
    
    if ($app) {
        Write-Host "Found existing app [AppId=$($app.AppId)] [ObjectId=$($app.Id)]"
        $ReplyUrlsOk = $true
        ForEach ($ReplyUrl in $ReplyUrls) {
            if (!$app.Web.RedirectUri -or !$app.Web.RedirectUri.Contains($ReplyUrl)) {
                $ReplyUrlsOk = $false
                Write-Host "Reply URL $ReplyUrl not present in app"
            }
        }

        if (-not $ReplyUrlsOk) {
            Write-Host "Setting reply URLs: $replyUrls"
            Update-AzADApplication -ObjectId $app.Id @PSBoundParameters | Out-Null
            $app = Get-AzADApplication -ObjectId $app.Id
        }
    } else {
        Write-Host "Creating new app"
        $PSBoundParameters.Remove("ReplyUrls") | Out-Null
        $additionalCreateParams = @{}
        if ($ReplyUrls.Count -gt 0) {
            $additionalCreateParams += @{ web = @{ redirectUris = $ReplyUrls } }
        }
        Write-Verbose "PSBoundParameters:`n$($PSBoundParameters | ConvertTo-Json -Depth 100)"
        Write-Verbose "additionalCreateParams:`n$($createParams | ConvertTo-Json -Depth 100)"

        $app = New-AzADApplication @PSBoundParameters @additionalCreateParams
        Write-Host "Created new app with AppId $($app.AppId) [IdentifierUri=$($app.IdentifierUri)]"
    }

    return $app
}
