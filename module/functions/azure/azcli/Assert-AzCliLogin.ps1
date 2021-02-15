# <copyright file="Assert-AzCliLogin.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Ensures a valid login to the azure-cli.

.DESCRIPTION
Verifies you have a valid azure-cli access token or prompts for an interactive login.

For automation scenarios, the azure-cli credentials can be passed via environment variables:
  AZURE_CLIENT_ID
  AZURE_CLIENT_SECRET

.PARAMETER SubscriptionId
The target Azure Subscription ID.

.PARAMETER AadTenantId
The AzureAD Tenant ID associated with subscription.

.OUTPUTS
Returns the details of the logged-in account (i.e. the output from 'az account show').

#>
function Assert-AzCliLogin {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string] $SubscriptionId,
        [Parameter(Mandatory=$true)] [string] $AadTenantId
    )
    try {
        # check whether already logged-in
        [datetime]$currentTokenExpiry = & az account get-access-token --subscription $SubscriptionId -o tsv --query "expiresOn" 2>&1
        if ($currentTokenExpiry -le [datetime]::Now) {
            throw
        }
    }
    catch {
        # login with the typical environment variables, if available
        if ( (Test-Path env:\AZURE_CLIENT_ID) -and (Test-Path env:\AZURE_CLIENT_SECRET) ) {
            Write-Host "Performing azure-cli login as service principal via environment variables"
            Invoke-AzCli -Command ('login --service-principal -u "{0}" -p "{1}" --tenant $AadTenantId' -f $env:AZURE_CLIENT_ID, $env:AZURE_CLIENT_SECRET)
            if ($LASTEXITCODE -ne 0) {
                Write-Error "There was a problem logging into the Azure-cli using environment variable configuration - check any previous messages"
            }
        }
        # Azure pipeline processes seem to report themselves as interactive - at least on linux agents
        elseif ( [Environment]::UserInteractive -and !(Test-Path env:\SYSTEM_TEAMFOUNDATIONSERVERURI) ) {
            Invoke-AzCli -Command "login --tenant $AadTenantId" -SuppressConnectionValidation
            if ($LASTEXITCODE -ne 0) {
                Write-Error "There was a problem logging into the Azure-cli - check any previous messages"
            }
        }
        else {
            Write-Error "When running non-interactively the process must already be logged-in to the Azure-cli or have the SPN details setup in environment variables"
        }
    }

    Invoke-AzCli "account set --subscription $SubscriptionId" -SuppressConnectionValidation
    return (Invoke-AzCli "account show" -asJson -SuppressConnectionValidation)
}