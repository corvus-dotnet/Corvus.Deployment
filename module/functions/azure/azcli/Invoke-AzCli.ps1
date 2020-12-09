# <copyright file="Invoke-AzCli.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Invokes azure-cli commands and returns the results.

.DESCRIPTION
Provides a wrapper for invokes an azure-cli commands.

.PARAMETER Command
The azure-cli command you want to execute, excluding the 'az' reference.

.PARAMETER AsJson
Controls whether you expect the command to have a JSON response that you want returned as output.

.PARAMETER ExpectedExitCodes
An array of exit codes that will not be treated as signifying an error.

.OUTPUTS
When the '-AsJson' parameter is supplied, the JSON output from azure-cli will be returned as a hashtable.

#>
function Invoke-AzCli
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Command,
        
        [switch] $AsJson,
        
        [array] $ExpectedExitCodes = @(0)
    )

    $cmd = "az $command"
    if ($asJson) { $cmd = "$cmd -o json" }
    Write-Verbose "azcli cmd: $cmd"
    
    $ErrorActionPreference = 'Continue'     # azure-cli can sometimes write warnings to STDERR, which PowerShell treats as an error
    
    # Capture any error messages so they can be properly logged
    # NOTE: '-ErrorVariable' on Invoke-Expression seems only to work properly if the command-line contains some STDERR redirection,
    #       otherwise the error variable is always null.
    $res = Invoke-Expression "$cmd 2>''" -ErrorVariable azCliStdErr
    
    $diagnosticInfo = @"
StdOut:
$res
StdErr:
$azCliStdErr
"@
    $ErrorActionPreference = 'Stop'
    if ($expectedExitCodes -inotcontains $LASTEXITCODE) {
        Write-Error "azure-cli failed with exit code: $LASTEXITCODE`nDiagnostic information follows:`nCommand: $cmd`n$diagnosticInfo"
    }

    Write-Verbose $diagnosticInfo

    if ($asJson) {
        return ($res | ConvertFrom-Json -Depth 30 -AsHashtable)
    }
}