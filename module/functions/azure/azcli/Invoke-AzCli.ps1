function Invoke-AzCli
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $command,
        
        [switch] $asJson,
        
        [array] $expectedExitCodes = @(0)
    )

    $cmd = "az $command"
    if ($asJson) { $cmd = "$cmd -o json" }
    Write-Verbose "azcli cmd: $cmd"
    
    $ErrorActionPreference = 'Continue'     # azure-cli can sometimes write warnings to STDERR, which PowerShell treats as an error
    $res = Invoke-Expression $cmd
    
    $ErrorActionPreference = 'Stop'
    if ($expectedExitCodes -inotcontains $LASTEXITCODE) {
        Write-Error "azure-cli failed with exit code: $LASTEXITCODE"
    }

    if ($asJson) {
        return ($res | ConvertFrom-Json)
    }
}