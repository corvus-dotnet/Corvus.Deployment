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
The body of the request to be invoked, represented as a hashtable or an array of hashtables.

.PARAMETER BodyFilePath
The path to the file containing the body of the request to be invoked.

.PARAMETER Headers
The HTTP headers required by the request to be invoked.  The "Content-Type" header will be automatically added if missing:

@{ "Content-Type" = "application/json" }

.PARAMETER ResourceForAuth
Resource url for which CLI should acquire a token from AAD in order to access the service. The token will be placed in
the Authorization header. By default, CLI can figure this out based on --url argument, unless you use ones not in the
list of "az cloud show --query endpoints"

.OUTPUTS
The JSON output from the underlying azure-cli command, in hashtable format.

#>

function Invoke-AzCliRestCommand
{
    [CmdletBinding(DefaultParameterSetName = 'Body as hashtable')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Body as hashtable')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Body as file')]
        [string] $Uri,
        
        [Parameter(ParameterSetName = 'Body as hashtable')]
        [Parameter(ParameterSetName = 'Body as file')]
        [ValidateSet("DELETE", "GET", "PATCH", "POST", "PUT")]
        [string] $Method = "GET",
        
        [Parameter(ParameterSetName = 'Body as hashtable')]
        $Body,

        [Parameter(Mandatory = $true, ParameterSetName = 'Body as file')]
        [string] $BodyFilePath,
        
        [Parameter(ParameterSetName = 'Body as hashtable')]
        [Parameter(ParameterSetName = 'Body as file')]
        [hashtable] $Headers = @{},

        [Parameter(ParameterSetName = 'Body as hashtable')]
        [Parameter(ParameterSetName = 'Body as file')]
        [string] $ResourceForAuth
    )

    # Ensure we always have the 'Content-Type' header
    if ( !$Headers.ContainsKey("Content-Type") ) {
        $Headers += @{ "Content-Type" = "application/json" }
    }

    # perform any query string escaping
    $uriEscaped = $Uri.Replace("'", "''")

    # start building up the 'az rest' command-line
    $cmdParts = @(
        "rest"
        "--uri '$uriEscaped'"
        "--method $Method"
    )

    if ($ResourceForAuth) {
        $cmdParts += "--resource $ResourceForAuth"
    }

    # Additional arguments for methods with body semantics
    if (@("PUT", "POST", "PATCH") -contains $Method) {
        switch ($PSCmdlet.ParameterSetName) {
            "Body as hashtable" {
                if ($Body -is [hashtable] -or ($Body -is [array] -and $Body[0] -is [hashtable])) {
                    $bodyAsJson = (ConvertTo-Json $Body -Depth 100 -Compress).replace('"', '\"').replace(':\', ': \').replace("'", "''")
                }
                else {
                    throw "The -Body parameter must be of type [hashtable] or [hashtable[]]"
                }
                break
            }
            "Body as file" {
                $bodyAsJson = "@$BodyFilePath"
                break
            }
        }
        
        $headersAsEscapedJsonString = (ConvertTo-Json $Headers -Compress).replace('"', '\"').replace(':\', ': \').replace("'", "''")

        $cmdParts += "--body '$bodyAsJson'"
        $cmdParts += "--headers '$headersAsEscapedJsonString'"
    }

    # The escaping we do for '$headersAsEscapedJsonString' above is incompatible with the revised argument parsing logic
    # in recent versions of PowerShell. To ensure backwards-compatibility we need to use the 'UseLegacyNativeCommandArgumentPassing'
    # option now offered by 'Invoke-AzCli', rather than updating the escaping logic.
    # REF: https://learn.microsoft.com/en-us/powershell/scripting/learn/experimental-features?view=powershell-7.4#psnativecommandargumentpassing
    $response = Invoke-AzCli -Command ($cmdParts -join " ") -AsJson -UseLegacyNativeCommandArgumentPassing
    return $response
}