# <copyright file="_getApiId.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Provides a convenient lookup for Azure API identifiers using 'friednly' names.

.DESCRIPTION
Provides a convenient lookup for Azure API identifiers using 'friednly' names.

.PARAMETER ApiName
The name of the API to lookup.

.NOTES
The supported API names are as follows:
@{
    "AzureGraph" = "00000002-0000-0000-c000-000000000000"
    "MSGraph"    = "00000003-0000-0000-c000-000000000000"
}

#>

function _getApiId
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("AzureGraph","MSGraph")]
        [string] $ApiName
    )

    $apiLookup = @{
        "AzureGraph" = "00000002-0000-0000-c000-000000000000"
        "MSGraph" = "00000003-0000-0000-c000-000000000000"
    }
    
    return $apiLookup[$ApiName]
}