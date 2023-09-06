# <copyright file="Update-TokenizedFiles.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Searches multiple files for occurences of multiple strings following a regular expression pattern and replaces them with the provided values.

.DESCRIPTION
Configuration that changes between different environments etc. is often represented by a tokenised value, which is updated before use.
For example, a file containing the following:

{
    "apiBaseUrl": "https://#{ApiServer}#/api"
}

This function allows such tokenised files to be easily updated with their actual values based on the configuration passed in the 'TokenValuePairs'
hashtable.

Using the following hashtable:

@{
    ApiServer = "myserver.nowhere.org"
}

Would result in the file being updated as shown below:

{
    "apiBaseUrl": "https://myserver.nowhere.org/api"
}

.NOTES
NOTE: When customising the 'TokenRegexFormatString', care must be taken to ensure that any characters that would other conflict with the format string
syntax are suitably escaped.  For example, the pattern used above requires the braces to be escaped: "\#\{{{0}\}}\#"

- Regex syntax requires '#', '{' and '}' need to be escaped with the backslash
- Format string syntax requires the '{' and '}' not related to the format string to be escaped by doubling them up


.PARAMETER FilesToProcess
The array of file paths that will have any tokenised values substituted.

.PARAMETER TokenRegexFormatString
The regular expression used to locate tokens to be replaced. The expression must contain a single format string placeholder (i.e. '{0}') to represent the name of the token.

.PARAMETER TokenValuePairs
A hashtable containing the mapping of tokens to their respective values.

#>

function Update-TokenizedFiles
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string[]] $FilesToProcess,
        [string] $TokenRegexFormatString = "\#\{{{0}\}}\#",     # the escaped curly brackets need to doubled-up to work properly with the format string
        [hashtable] $TokenValuePairs
    )

    $configCache = @{}
    $FilesToProcess | ForEach-Object {
        Write-Verbose "Caching file: $_"
        $configCache += @{ 
            $_ = @{
                contents = (get-content -raw $_)
                updated = $false
            }
        }
    }

    $TokenValuePairs.Keys | ForEach-Object {
        $token = $_
        $regexPattern = $TokenRegexFormatString -f $token
        Write-Verbose "Checking for $token"
        $configCache.Keys | ForEach-Object {
            if ($configCache[$_].contents -match $regexPattern) {
                Write-Host "Patching $token in $_"
                $configCache[$_].updated = $true
                $configCache[$_].contents = $configCache[$_].contents -replace $regexPattern,$TokenValuePairs[$token]
            }
        }
    }

    $configCache.Keys |
        Where-Object { $configCache[$_].updated } |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_)) {
                Write-Host "Saving $_"
                Set-Content -Path $_ `
                            -Value $configCache[$_].contents
            }
        }
}
