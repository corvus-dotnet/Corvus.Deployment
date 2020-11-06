# <copyright file="Invoke-CommandWithRetry.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Provides retry logic for PowerShell ScriptBlock execution.

.DESCRIPTION
Provides retry logic for PowerShell ScriptBlock execution.

.PARAMETER Command
Sets the scriptblock to be executed.

.PARAMETER RetryCount
Sets the maximum retry attempts.

.PARAMETER RetryDelay
Sets the delay (in seconds) between retry attempts.

#>
function Invoke-CommandWithRetry
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [scriptblock] $Command,

        [int] $RetryCount = 5,

        [int] $RetryDelay = 5
    )

    $currentRetry = 0
    $success = $false

    # Private functions for mocking purposes
    function _logWarning($delay)
    {
        Write-Warning "Sleeping for $delay before retrying command"
    }

    do
    {
        Write-Verbose ("Executing command with retry:`n{0}" -f ($Command | Out-String))
        try
        {
            $result = Invoke-Command $command -ErrorAction Stop
            $success = $true
        }
        catch
        {   
            if ($currentRetry -ge $RetryCount) {
                throw "Exceeding retry limit when running command"
            }
            else {
                _logWarning $RetryDelay
                Start-Sleep -s $RetryDelay
            }
            $currentRetry++
        }
    } while (!$success);

    return $result
}
