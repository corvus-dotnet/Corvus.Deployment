# <copyright file="Assert-AzureAdGroup.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Creates or updates a AzureAD group.

.DESCRIPTION
Uses the azure-cli to configure an AzureAD group.

.PARAMETER Name
The display name of the group.

.PARAMETER EmailName
The username portion of the email address associated with the group

.PARAMETER Description
The description of the group

.OUTPUTS
AzureAD group definition object

#>
function Assert-AzureADGroup
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $EmailName,

        [Parameter()]
        [string] $Description
    )

    $cmdArgs = @(
        '--display-name "{0}"' -f $Name
        '--mail-nickname "{0}"' -f $EmailName
    )

    if ($Description) {
        $cmdArgs += '--description "{0}"' -f $Description
    }

    $cmd = "ad group create {0}" -f ($cmdArgs -join ' ')
    Invoke-AzCli -Command $cmd -asJson
}