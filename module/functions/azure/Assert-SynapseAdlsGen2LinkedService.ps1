# <copyright file="Assert-SynapseAdlsGen2LinkedService.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Creates or updates a linked service that connects an ADLS Gen2 storage account to a Synapse workspace

.DESCRIPTION
Creates or updates a linked service that connects an ADLS Gen2 storage account to a Synapse workspace.

The Synapse workspace managed identity must have access the underlying storage account.

The service principal credentials can be passed as parameters, or defined in the following environment variables:
    AZURE_CLIENT_ID
    AZURE_CLIENT_SECRET

.PARAMETER WorkspaceName
The Synapse workspace name

.PARAMETER StorageAccountName
The ADLS Gen2 storage account to link to

.PARAMETER ClientId
The AzureAD AppId of a service principal with Admin access to the Synapse workspace

.PARAMETER ClientSecret
The password for the service principal with Admin access to the Synapse workspace

.OUTPUTS
Synapse LinkedService object

.EXAMPLE



#>
function Assert-SynapseAdlsGen2LinkedService
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [string] $WorkspaceName,

        [Parameter(Mandatory=$True)]
        [string] $StorageAccountName,

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

    # Check whether we have a valid AzPowerShell connection
    _EnsureAzureConnection -AzPowerShell -ErrorAction Stop

    $token = Get-MsalToken -ClientId $ClientId `
                           -ClientSecret $ClientSecret `
                           -TenantId $script:moduleContext.AadTenantId `
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

    $isComplete = $false
    $retry = 0
    $maxRetries = 5
    # NOTE: Potentially consider referencing eTags if we need more control over waiting for updates
    if ($resp.state -in @('Creating','Updating')) {
        Write-Host "Waiting for LinkedService operation to complete..."
        while(!$isComplete -and $retry -le $maxRetries) {
            Start-Sleep -Seconds 10
            try {
                $linkedService = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
                $isComplete = $true
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq 404) {
                    $retry++
                    continue
                }
                else {
                    throw $_
                }
            }
        }
    }

    if (!$isComplete) {
        throw "Timeout whilst waiting for LinkedService configuration to complete"
    }

    $linkedService
}
