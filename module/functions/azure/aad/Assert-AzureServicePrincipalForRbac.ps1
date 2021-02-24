# <copyright file="Assert-AzureServicePrincipalForRbac.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that a suitable Azure AD application & service principal exists, creating if necessary.

.DESCRIPTION
Ensures that a suitable Azure AD application & service principal exists.  Uses the Azure CLI to create
it if necessary.

.PARAMETER Name
The display name of the Azure AD identity.

.OUTPUTS
Returns a tuple containing a hashtable representing the JSON object describing the Azure AD service principal and
it's client secret. Where the client secret is not avilablae (e.g. the identity aleady exists) $null will be returned
for this element.

e.g.
@(
    @{ <service-principal-definition> },
    "<client-secret>"
)

#>

function Assert-AzureServicePrincipalForRbac
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name
    )

    $spSecret = $null
    $checkSpArgs = @(
        "ad sp list"
        "--display-name $Name"
    )
    $existingSp = Invoke-AzCli $checkSpArgs -asJson

    if (!$existingSp) {
        # create a new service principal
        Write-Host "Registering new SPN"
        $newSpArgs = @(
            "ad sp create-for-rbac"
            "-n $Name"
            "--skip-assignment"
        )
        if ($PSCmdlet.ShouldProcess($Name, "Create Service Principal")) {
            $newSp = Invoke-AzCli $newSpArgs -asJson
            Write-Host ("Complete - ApplicationId={1}" -f $Name, $newSp.appId)
            $spSecret = $newSp.password
        
            $checkNewSpArgs = @(
                "ad sp list"
                "--display-name $Name"
            )
            $existingSp = Invoke-AzCli $checkNewSpArgs -asJson
            if (!$existingSp) {
                # TODO: retry?
                throw "Unexpected error - the newly created service principal '$Name' could not be found"
            }
        }
    }
    else {
        Write-Host ("SPN '{0}' already exists - skipping" -f $existingSp.appDisplayName)
    }

    return $existingSp,$spSecret
}