$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$here = Split-Path -Parent $PSCommandPath
$pesterVer = '4.10.1'
try {
    [array]$existingModule = Get-Module -ListAvailable Pester
    if (!$existingModule -or ($existingModule.Version -notcontains $pesterVer)) {
        Install-Module Pester -RequiredVersion $pesterVer -Force -Scope CurrentUser -SkipPublisherCheck
    }
    Import-Module Pester -RequiredVersion $pesterVer

    # Install other modules required by the tests
    $latestExistingAzResourcesModule = Get-Module -ListAvailable Az.Resources | Select -ExpandProperty Version | Sort -Descending | Select -First 1
    if (!$latestExistingAzResourcesModule -or $latestExistingAzResourcesModule -lt "6.5.3") {
        Write-Host "Installing module: Az.Resources ..."
        Install-Module Az.Resources -MinimumVersion "6.5.3" -Force -Scope CurrentUser
    }

    $results = Invoke-Pester $here/module `
                         -ExcludeTag Integration `
                         -PassThru `
                         -Show Describe,Failed,Summary `
                         -OutputFormat "NUnitXml" `
                         -OutputFile (Join-Path $here "PesterTestResults.xml")

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
