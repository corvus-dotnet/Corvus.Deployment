$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath
$pesterVer = '4.10.1'
try {
    # Display what version of Azure PowerShell we have available
    Get-Module Az.Resources -ListAvailable | Format-Table | Out-string | Write-Host

    [array]$existingModule = Get-Module -ListAvailable Pester
    if (!$existingModule -or ($existingModule.Version -notcontains $pesterVer)) {
        Install-Module Pester -RequiredVersion $pesterVer -Force -Scope CurrentUser -SkipPublisherCheck
    }
    Import-Module Pester
    $results = Invoke-Pester $here/module -PassThru -Show Describe,Failed,Summary

    if ($results.FailedCount -gt 0) {
        throw ("{0} out of {1} tests failed - check previous logging for more details" -f $results.FailedCount, $results.TotalCount)
    }
}
catch {
    Write-Output ("::error file={0},line={1},col={2}::{3}" -f `
                        $_.InvocationInfo.ScriptName,
                        $_.InvocationInfo.ScriptLineNumber,
                        $_.InvocationInfo.OffsetInLine,
                        $_.Exception.Message)

    exit 1
}
