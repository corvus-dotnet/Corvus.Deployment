# <copyright file="_HandleRestError.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Checks the HTTP response object returned by 'Invoke-AzRestMethod' for errors.

.DESCRIPTION
Checks the HTTP response object returned by 'Invoke-AzRestMethod' for errors.

.PARAMETER Response
The response object return by 'Invoke-AzRestMethod'.

#>

function _HandleRestError
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Microsoft.Azure.Commands.Profile.Models.PSHttpResponse] $Response
    )

    # NOTE: 
    #       _EnsureAzureConnection
    #       Suppress 'validate the Azure connection' test.
    #       The inclusion of 'Invoke-AzRestMethod' in the comments above cause a false positive.

    if ($Response.StatusCode -ge 400) {
        throw ($Response.Content | ConvertFrom-Json -Depth 100).error | ConvertTo-Json -Depth 100
    }

    return $Response
}