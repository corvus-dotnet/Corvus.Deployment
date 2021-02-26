# <copyright file="Assert-AzureCliExtension.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures that an Azure CLI extension is available.

.DESCRIPTION
Ensures that an Azure CLI extension is available.

.PARAMETER Name
The name of the Azure DevOps extension.

.OUTPUTS
Returns a hashtable representing the JSON object describing the Azure CLI extension.

#>
function Assert-AzureCliExtension
{
     [CmdletBinding()]
     param (
         [Parameter(Mandatory=$true)]
         [string] $Name
     )

     $queryArgs = @(
        "extension list"
        "--query=`"[?name=='$Name']`""
     )
     $isInstalled = Invoke-AzCli $queryArgs -asJson

    if (!$isInstalled) {
        Write-Host "Installing the $Name cli extension..."
        Invoke-AzCli "extension add --name $Name"

        $isInstalled = Invoke-AzCli $queryArgs -asJson
    }

    return $isInstalled
}