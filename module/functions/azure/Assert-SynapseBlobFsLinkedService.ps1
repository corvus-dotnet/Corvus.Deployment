#requires -Modules MSAL.PS
function Assert-SynapseBlobFsLinkedService
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string] $WorkspaceName,

        [Parameter(Mandatory=$True)]
        [string] $StorageAccountName,

        [Parameter(Mandatory=$True)]
        [string] $StorageAccountKey,

        [Parameter()]
        [guid] $ClientId = [guid]::Empty,

        [Parameter()]
        [securestring] $ClientSecret = $null
    )

    # Setup request for a linked service that uses the Synapse managed identity
    $body = @{
        properties = @{
            type = "AzureBlobFS"
            typeProperties = @{
                url = "https://$($StorageAccountName).dfs.core.windows.net"
            }
            connectVia = @{
                referenceName = "AutoResolveIntegrationRuntime"
                type = "IntegrationRuntimeReference"
            }
        }
    }
    
    if ($ClientId -eq [guid]::Empty -and [string]::IsNullOrEmpty($env:AZURE_CLIENT_ID)) {
        throw "Missing ClientId - You must provide the '-ClientId' parameter or set the 'AZURE_CLIENT_ID' environment variable"
    }
    elseif ($ClientId -eq [guid]::Empty) {
        $ClientId = $env:AZURE_CLIENT_ID
    }

    # use PS7 null conditional assignment 
    $ClientSecret ??= $env:AZURE_CLIENT_SECRET | ConvertTo-SecureString -AsPlainText -Force
    if ($null -eq $ClientSecret) {
        throw "Missing ClientSecret - You must provide the '-ClientSecret' parameter or set the 'AZURE_CLIENT_SECRET' environment variable"
    }

    $token = Get-MsalToken -ClientId $ClientId `
                           -ClientSecret $ClientSecret `
                           -TenantId $script:AadTenantId `
                           -Scopes https://dev.azuresynapse.net/.default
    
    $headers = @{
        ContentType = "application/json"
        Authorization = "Bearer $($token.AccessToken)"
    }

    $uri = "https://$($WorkspaceName).dev.azuresynapse.net/linkedservices/$($StorageAccountName)?api-version=2019-06-01-preview"
    $resp = Invoke-RestMethod -Uri $uri `
                              -Method Put `
                              -Headers $headers `
                              -Body ($body|ConvertTo-Json -Compress -Depth 10)

    if ($resp.state -in @('Creating','Updating')) {
        Write-Host "Waiting for LinkedService operation to complete..."
        while($true) {
            Start-Sleep -Seconds 10
            try {
                $linkedService = Invoke-RestMethod -Uri $uri -Headers $headers
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq 404) {
                    continue
                }
                else {
                    throw $_
                }
            }
            break
        }
    }

    $linkedService
}
