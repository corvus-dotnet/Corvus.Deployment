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

.PARAMETER IdentifierUri
The URL to the application homepage. Can only be updated for an existing AzureAD application when also updating the 'ReplyUrls' property.

.PARAMETER ReplyUrls
The application reply urls. Can be updated for an existing AzureAD application.

.PARAMETER EnableAccessTokenIssuance
When true, allows the AzureAD application to issue access tokens (used for implicit flow). Can only be updated for an existing AzureAD application when also updating the 'ReplyUrls' property.

.PARAMETER EnableIdTokenIssuance
When true, allows the AzureAD application to issue ID tokens (used for implicit & hybrid flows). Can only be updated for an existing AzureAD application when also updating the 'ReplyUrls' property.

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
        [string[]] $ReplyUrls,

        [Parameter()]
        [switch] $EnableAccessTokenIssuance,

        [Parameter()]
        [switch] $EnableIdTokenIssuance
    )

    # Helper functions
    function _buildAppWebConfig($BoundParameters)
    {
        # Construct an object that represents the 'webApplication' type
        # ref: https://learn.microsoft.com/en-us/graph/api/resources/webapplication?view=graph-rest-1.0
        $appWebConfig = @{
            implicitGrantSettings = @{
                enableAccessTokenIssuance = $EnableAccessTokenIssuance.ToBool()
                enableIdTokenIssuance = $EnableIdTokenIssuance.ToBool()
            }
        }
        if ($BoundParameters.ContainsKey("ReplyUrls")) {
            # Use the ReplyUrls that have been specified on the call to Assert-AzureAdApp
            $appWebConfig += @{ redirectUris = $ReplyUrls }
        }
        elseif ($app) {
            # ReplyUrls not specified, use the app's existing values
            $appWebConfig += @{ redirectUris = $app.Web.redirectUri }
        }
        else {
            # ReplyUrls not specified and app does not yet exist
            $appWebConfig += @{ redirectUris = @() }
        }
        return $appWebConfig
    }

    #
    # Main implementation
    #

    # Check whether we have a valid AzPowerShell connection, but no subscription-level access is required
    _EnsureAzureConnection -AzPowerShell -TenantOnly -ErrorAction Stop | Out-Null
    
    Write-Host "Ensuring Azure AD application {$DisplayName} exists..."

    $app = Get-AzADApplication -DisplayNameStartWith $DisplayName | `
                Where-Object {$_.DisplayName -eq $DisplayName}
    
    if ($app) {
        Write-Host "Found existing app [AppId=$($app.AppId)] [ObjectId=$($app.Id)]"
        $appNeedsUpdating = $false
        $ReplyUrlsOk = $true
        ForEach ($ReplyUrl in $ReplyUrls) {
            if (!$app.Web.RedirectUri -or !$app.Web.RedirectUri.Contains($ReplyUrl)) {
                $ReplyUrlsOk = $false
                Write-Host "Reply URL $ReplyUrl not present in app"
            }
        }

        # Check whether 'web' settings need updating
        if (
            !$ReplyUrlsOk -or 
            ($app.Web.ImplicitGrantSetting.EnableAccessTokenIssuance -ne $EnableAccessTokenIssuance) -or 
            ($app.Web.ImplicitGrantSetting.EnableIdTokenIssuance -ne $EnableIdTokenIssuance)
        ) {
            $additionalUpdateParams = @{
                objectId = $app.Id
                web = _buildAppWebConfig($PSBoundParameters)
            }
            $appNeedsUpdating = $true
        }

        # Check whether other optional settings need to be updated
        if ($PSBoundParameters.ContainsKey("IdentifierUri") -and $app.IdentifierUri -ne $IdentifierUri) {
            $appNeedsUpdating = $true
        }

        if ($appNeedsUpdating) {
            Write-Host "Updating app"
            # Remove parameters that cannot be 'splatted' into Update-AzADApplication
            $PSBoundParameters.Remove("ReplyUrls") | Out-Null
            $PSBoundParameters.Remove("EnableAccessTokenIssuance") | Out-Null
            $PSBoundParameters.Remove("EnableIdTokenIssuance") | Out-Null

            Write-Verbose "PSBoundParameters:`n$($PSBoundParameters | ConvertTo-Json -Depth 100)"
            Write-Verbose "additionalUpdateParams:`n$($additionalUpdateParams | ConvertTo-Json -Depth 100)"
            Update-AzADApplication @PSBoundParameters @additionalUpdateParams | Out-Null
            $app = Get-AzADApplication -ObjectId $app.Id
        }
    } else {
        Write-Host "Creating new app"
        $additionalCreateParams = @{}
        if ($ReplyUrls.Count -gt 0) {
            $additionalCreateParams += @{
                web = _buildAppWebConfig($PSBoundParameters)
            }
        }
        # Remove parameters that cannot be 'splatted' into New-AzADApplication
        $PSBoundParameters.Remove("ReplyUrls") | Out-Null
        $PSBoundParameters.Remove("EnableAccessTokenIssuance") | Out-Null
        $PSBoundParameters.Remove("EnableIdTokenIssuance") | Out-Null
        Write-Verbose "PSBoundParameters:`n$($PSBoundParameters | ConvertTo-Json -Depth 100)"
        Write-Verbose "additionalCreateParams:`n$($createParams | ConvertTo-Json -Depth 100)"

        $app = New-AzADApplication @PSBoundParameters @additionalCreateParams
        Write-Host "Created new app with AppId $($app.AppId) [IdentifierUri=$($app.IdentifierUri)]"
    }

    return $app
}
