function Assert-AzureADGroup
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $EmailName,

        [Parameter()]
        [string] $Description
    )

    $cmdArgs = @(
        '--display-name "{0}"' -f $Name
        '--mail-nickname "{0}"' -f $EmailName
    )

    if ($Description) {
        $cmdArgs += '--description "{0}"' -f $Description
    }

    $cmd = "ad group create {0}" -f ($cmdArgs -join ' ')
    Invoke-AzCli -Command $cmd -asJson
}