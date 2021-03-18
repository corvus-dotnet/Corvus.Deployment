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
    function _logRetry($delay,$errorRecord)
    {
        Write-Warning ("Command failed - $($errorRecord.Exception.Message) - retrying in {0} seconds" -f $delay)
    }

    do
    {
        Write-Verbose ("Executing command with retry:`n{0}" -f ($Command | Out-String))
        try
        {
            $result = Invoke-Command $command -ErrorAction Stop
            Write-Verbose ("Command succeeded." -f $Command)
            $success = $true

            # It is helpful to explicitly log when it succeeds after having to retry
            if ($currentRetry -gt 0) {
                Write-Host "Command succeeded on retry attempt: $currentRetry"
            }
        }
        catch
        {   
            if ($currentRetry -ge $RetryCount) {
                Write-Warning ("Exceeded retry limit when running command [{0}]" -f $Command)
                throw $_
            }
            else {
                _logRetry $RetryDelay $_
                Start-Sleep -s $RetryDelay
            }
            $currentRetry++
        }
    } while (!$success);

    return $result
}
