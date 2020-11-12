# <copyright file="Invoke-AzCliRestCommand.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Provides a wrapper around the 'az rest' command included with the azure-cli.

.DESCRIPTION
Provides a wrapper around the 'az rest' command included with the azure-cli, handling all the necessary JSON escaping.

.PARAMETER Uri
The Uri of the request to be invoked.

.PARAMETER Method
The REST method of the request to be invoked.

.PARAMETER Body
The body of the request to be invoked.

.PARAMETER Headers
The HTTP headers required by the request to be invoked.

.OUTPUTS
The JSON output from the underlying azure-cli command, in hashtable format.

#>

function Invoke-AzCliRestCommand
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Uri,
        
        [Parameter()]
        [ValidateSet("DELETE", "GET", "PATCH", "POST", "PUT")]
        [string] $Method = "GET",
        
        [Parameter()]
        [hashtable] $Body,
        
        [Parameter()]
        [hashtable] $Headers
    )

    if (@("GET", "DELETE") -contains $Method) {
        $uriEscaped = $Uri.Replace("'", "''")

        $response = Invoke-AzCli -Command "rest --uri '$uriEscaped' --method '$Method'" -AsJson

        return $response
    }
    else {
        $bodyAsEscapedJsonString = (ConvertTo-Json $Body -Depth 30 -Compress).replace('"', '\"').replace(':\', ': \').replace("'", "''")
        $headersAsEscapedJsonString = (ConvertTo-Json $Headers -Compress).replace('"', '\"').replace(':\', ': \').replace("'", "''")

        $response = Invoke-AzCli -Command "rest --uri '$Uri' --method '$Method' --body '$bodyAsEscapedJsonString' --headers '$headersAsEscapedJsonString'" -AsJson

        return $response
    }
}