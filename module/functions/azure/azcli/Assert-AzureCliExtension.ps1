function Assert-AzureCliExtension
{
     [CmdletBinding()]
     param (
         [Parameter()]
         [TypeName] $Name
     )

     $queryArgs = @(
        "extension list"
        "--query=`"[?name=='$Name']`""
     )
     $isInstalled = Invoke-AzCli $queryArgs -asJson

    if (!$isInstalled) {
        Write-Host "Installing the $Name cli extension..."
        Invoke-AzCli "extension add --name $Name"

        $isInstalled = Invoke-AzCli $queryArgs -asJson
    }

    return $isInstalled
}