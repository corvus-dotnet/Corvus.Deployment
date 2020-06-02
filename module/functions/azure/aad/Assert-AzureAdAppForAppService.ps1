# <copyright file="Assert-AzureAdAppForAppService.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an AzureAD application for use with an Azure AppService exists.

.DESCRIPTION
For AzureAD applications that don't already exist, one will be created with a '.azurewebsites.net'
homepage URI and be configured with the SignInAndReadProfile required access.

.PARAMETER AppName
The name of the application.

.PARAMETER AppId
For existing applications and scenarios where suitable Azure graph access is not available, the
application be specified by its ApplicationID.

.OUTPUTS
Microsoft.Azure.Commands.ActiveDirectory.PSADApplication
#>
function Assert-AzureAdAppForAppService
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $AppName,

        [string] $AppId
    )

    if ( !(Test-AzureGraphAccess) ) {
        if (-not $AppId) {
            Write-Error "AppId for $AppName was not supplied and access to the Azure AD graph is not available. Either run this in a context where graph access is available, or pass this app id in as an argument." 
        }
        $adApp = Get-AzADApplication -ApplicationId $AppId
        Write-Host ("AppId for {0} ({1}) is {2}" -f $AppName, $AppName, $AppId)
        return $adApp
    }

    $EasyAuthCallbackTail = ".auth/login/aad/callback"

    $AppUri = "https://" + $AppName + ".azurewebsites.net/"

    # When we add APIM support, this would need to use the public-facing service root, assuming
    # we still actually want callback URI support.
    $ReplyUrls = @(($AppUri + $EasyAuthCallbackTail))
    $app = Assert-AzureAdApp -DisplayName $AppName `
                             -AppUri $AppUri `
                             -ReplyUrls $ReplyUrls

    Write-Host ("AppId for {0} ({1}) is {2}" -f $AppName, $AppName, $app.ApplicationId)

    $Principal = Get-AzAdServicePrincipal -ApplicationId $app.ApplicationId
    if (-not $Principal)
    {
        $newSp = New-AzAdServicePrincipal -ApplicationId $app.ApplicationId -DisplayName $AppName -SkipAssignment
    }

    $GraphApiAppId = "00000002-0000-0000-c000-000000000000"
    $SignInAndReadProfileScopeId = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
    $manifest = Assert-RequiredResourceAccessContains `
                                -App $app `
                                -ResourceId $GraphApiAppId `
                                -AccessRequirements @( @{Id=$SignInAndReadProfileScopeId; Type="Scope"} )

    return $app
}