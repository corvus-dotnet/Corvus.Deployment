# <copyright file="Get-AdzoOrganisationUrl.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Returns the full URL of an Azure DevOps Organisation.

.DESCRIPTION
Returns the full URL of an Azure DevOps Organisation.

.PARAMETER Name
The Organisation name.

#>
function Get-AdzoOrganisationUrl
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Name
    )

    return "https://dev.azure.com/$Name"
}